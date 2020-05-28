import CallKit
import AVFoundation

class NativeCallInterface: NSObject {
    
    private let provider: CXProvider
    private let callController = CXCallController()
    
    private unowned var service: CallService!
    
    private var pendingAnswerAction: CXAnswerCallAction?
    
    required init(manager: CallService) {
        self.service = manager
        let config = CXProviderConfiguration(localizedName: Bundle.main.displayName)
        config.ringtoneSound = R.file.callCaf.fullName
        config.iconTemplateImageData = R.image.call.ic_mixin()?.pngData()
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportsVideo = false
        config.supportedHandleTypes = [.generic]
        config.includesCallsInRecents = false
        self.provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: nil)
    }
    
    @available(*, unavailable)
    override init() {
        fatalError()
    }
    
    func reportImmediateFailureCall() {
        let uuid = UUID()
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: "")
        update.localizedCallerName = ""
        provider.reportNewIncomingCall(with: uuid, update: update, completion: { error in })
        provider.reportCall(with: uuid, endedAt: nil, reason: .failed)
    }
    
    func reportNewIncomingCall(uuid: UUID, userId: String, username: String, completion: @escaping CallInterfaceCompletion) {
        pendingAnswerAction = nil
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: userId)
        update.localizedCallerName = username
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false
        update.hasVideo = false
        provider.reportNewIncomingCall(with: uuid, update: update, completion: completion)
    }
    
}

extension NativeCallInterface: CallInterface {
    
    func requestStartCall(uuid: UUID, handle: CallHandle, completion: @escaping CallInterfaceCompletion) {
        pendingAnswerAction = nil
        let action = CXStartCallAction(call: uuid, handle: handle.cxHandle)
        callController.requestTransaction(with: action, completion: completion)
    }
    
    func requestAnswerCall(uuid: UUID) {
        service.answerCall(uuid: uuid, completion: nil)
    }
    
    func requestEndCall(uuid: UUID, completion: @escaping CallInterfaceCompletion) {
        pendingAnswerAction = nil
        let action = CXEndCallAction(call: uuid)
        callController.requestTransaction(with: action, completion: completion)
    }
    
    func requestSetMute(uuid: UUID, muted: Bool, completion: @escaping CallInterfaceCompletion) {
        let action = CXSetMutedCallAction(call: uuid, muted: muted)
        callController.requestTransaction(with: action, completion: completion)
    }
    
    func reportNewIncomingCall(_ call: Call, completion: @escaping CallInterfaceCompletion) {
        reportNewIncomingCall(uuid: call.uuid,
                              userId: call.opponentUser.userId,
                              username: call.opponentUser.fullName,
                              completion: completion)
    }
    
    func reportCall(uuid: UUID, endedByReason reason: CXCallEndedReason) {
        pendingAnswerAction = nil
        provider.reportCall(with: uuid, endedAt: nil, reason: reason)
    }
    
    func reportOutgoingCallStartedConnecting(uuid: UUID) {
        provider.reportOutgoingCall(with: uuid, startedConnectingAt: nil)
    }
    
    func reportOutgoingCall(uuid: UUID, connectedAtDate date: Date) {
        provider.reportOutgoingCall(with: uuid, connectedAt: date)
    }
    
    func reportIncomingCall(uuid: UUID, connectedAtDate date: Date) {
        guard let action = pendingAnswerAction, action.callUUID == uuid else {
            return
        }
        action.fulfill()
        pendingAnswerAction = nil
    }
    
}

extension NativeCallInterface: CXProviderDelegate {
    
    func providerDidReset(_ provider: CXProvider) {
        pendingAnswerAction = nil
        service.clean()
    }
    
    func providerDidBegin(_ provider: CXProvider) {
        
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        if let handle = CallHandle(cxHandle: action.handle) {
            service.startCall(uuid: action.callUUID, handle: handle) { (success) in
                success ? action.fulfill() : action.fail()
            }
        } else {
            service.alert(error: .invalidHandle)
            action.fail()
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        service.answerCall(uuid: action.callUUID) { (success) in
            if success {
                self.pendingAnswerAction = action
            } else {
                action.fail()
            }
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        service.endCall(uuid: action.callUUID)
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        service.isMuted = action.isMuted
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        if let call = service.activeCall, call.isOutgoing, !call.hasReceivedRemoteAnswer {
            service.ringtonePlayer.play(ringtone: .outgoing)
        }
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        
    }
    
}
