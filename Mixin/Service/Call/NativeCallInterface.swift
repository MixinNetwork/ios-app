import CallKit
import AVFoundation

class NativeCallInterface: NSObject {
    
    private let provider: CXProvider
    private let callController = CXCallController()
    
    private unowned var manager: CallManager!
    
    private var pendingAnswerAction: CXAnswerCallAction?
    
    required init(manager: CallManager) {
        self.manager = manager
        let config = CXProviderConfiguration(localizedName: Bundle.main.displayName)
        config.ringtoneSound = "call.caf"
        config.iconTemplateImageData = R.image.call.ic_mixin()?.pngData()
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportsVideo = false
        config.supportedHandleTypes = [.generic]
        self.provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: nil)
    }
    
    @available(*, unavailable)
    override init() {
        fatalError()
    }
    
}

extension NativeCallInterface: CallInterface {
    
    func requestStartCall(uuid: UUID, handle: CallHandle, completion: @escaping CallInterfaceCompletion) {
        pendingAnswerAction = nil
        let action = CXStartCallAction(call: uuid, handle: handle.cxHandle)
        callController.requestTransaction(with: action, completion: completion)
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
    
    func reportNewIncomingCall(uuid: UUID, handle: CallHandle, localizedCallerName: String, completion: @escaping CallInterfaceCompletion) {
        pendingAnswerAction = nil
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat)
        let update = CXCallUpdate()
        update.remoteHandle = handle.cxHandle
        update.localizedCallerName = localizedCallerName
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false
        update.hasVideo = false
        provider.reportNewIncomingCall(with: uuid, update: update, completion: completion)
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
        manager.clean()
    }
    
    func providerDidBegin(_ provider: CXProvider) {
        
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        if let handle = CallHandle(cxHandle: action.handle) {
            manager.startCall(uuid: action.callUUID, handle: handle) { (success) in
                success ? action.fulfill() : action.fail()
            }
        } else {
            manager.alert(error: .invalidHandle)
            action.fail()
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        manager.answerCall(uuid: action.callUUID) { (success) in
            if success {
                self.pendingAnswerAction = action
            } else {
                action.fail()
            }
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        manager.endCall(uuid: action.callUUID)
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        manager.isMuted = action.isMuted
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        if let call = manager.call, call.isOutgoing {
            manager.ringtonePlayer?.play()
        }
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        
    }
    
}
