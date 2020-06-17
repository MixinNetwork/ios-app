import CallKit
import AVFoundation

class NativeCallInterface: NSObject {
    
    private let provider: CXProvider
    private let callController = CXCallController()
    
    private unowned let service: CallService
    
    private var pendingAnswerAction: CXAnswerCallAction?
    private var unansweredIncomingCallUUIDs = Set<UUID>()
    
    required init(service: CallService) {
        self.service = service
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
        provider.setDelegate(self, queue: service.queue)
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
    
    func reportIncomingCall(uuid: UUID, userId: String, username: String, completion: @escaping CallInterfaceCompletion) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: userId)
        update.localizedCallerName = username
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false
        update.hasVideo = false
        if unansweredIncomingCallUUIDs.contains(uuid) {
            provider.reportCall(with: uuid, updated: update)
            completion(nil)
            if let action = pendingAnswerAction, uuid == action.callUUID, service.hasPendingSDP(for: uuid) {
                unansweredIncomingCallUUIDs.remove(uuid)
                service.answerCall(uuid: action.callUUID) { (success) in
                    if !success {
                        action.fail()
                        self.pendingAnswerAction = nil
                    }
                }
            }
        } else {
            unansweredIncomingCallUUIDs.insert(uuid)
            provider.reportNewIncomingCall(with: uuid, update: update, completion: completion)
        }
    }
    
}

extension NativeCallInterface: CallInterface {
    
    func requestStartCall(uuid: UUID, handle: CallHandle, completion: @escaping CallInterfaceCompletion) {
        let action = CXStartCallAction(call: uuid, handle: handle.cxHandle)
        callController.requestTransaction(with: action) { (error) in
            if error == nil {
                let update = CXCallUpdate()
                update.localizedCallerName = handle.name
                update.supportsHolding = false
                update.supportsGrouping = false
                update.supportsUngrouping = false
                update.supportsDTMF = false
                update.hasVideo = false
                self.provider.reportCall(with: uuid, updated: update)
            }
            completion(error)
        }
    }
    
    func requestAnswerCall(uuid: UUID) {
        assertionFailure("This is not expected to happen")
    }
    
    func requestEndCall(uuid: UUID, completion: @escaping CallInterfaceCompletion) {
        if let action = pendingAnswerAction, uuid == action.callUUID {
            action.fail()
            pendingAnswerAction = nil
        }
        unansweredIncomingCallUUIDs.remove(uuid)
        let action = CXEndCallAction(call: uuid)
        callController.requestTransaction(with: action, completion: completion)
    }
    
    func requestSetMute(uuid: UUID, muted: Bool, completion: @escaping CallInterfaceCompletion) {
        let action = CXSetMutedCallAction(call: uuid, muted: muted)
        callController.requestTransaction(with: action, completion: completion)
    }
    
    func reportIncomingCall(_ call: Call, completion: @escaping CallInterfaceCompletion) {
        reportIncomingCall(uuid: call.uuid,
                           userId: call.remoteUserId,
                           username: call.remoteUsername,
                           completion: completion)
    }
    
    func reportCall(uuid: UUID, endedByReason reason: CXCallEndedReason) {
        if let action = pendingAnswerAction, uuid == action.callUUID {
            action.fail()
            pendingAnswerAction = nil
        }
        unansweredIncomingCallUUIDs.remove(uuid)
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
        pendingAnswerAction?.fail()
        pendingAnswerAction = nil
        service.closeAll()
    }
    
    func providerDidBegin(_ provider: CXProvider) {
        
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        guard let handle = CallHandle(cxHandle: action.handle) else {
            service.alert(error: .invalidHandle)
            action.fail()
            return
        }
        service.startCall(uuid: action.callUUID, handle: handle) { (success) in
            success ? action.fulfill() : action.fail()
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        if service.hasPendingSDP(for: action.callUUID) {
            unansweredIncomingCallUUIDs.remove(action.callUUID)
            service.answerCall(uuid: action.callUUID) { (success) in
                if success {
                    self.pendingAnswerAction = action
                } else {
                    action.fail()
                }
            }
        } else {
            pendingAnswerAction = action
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
