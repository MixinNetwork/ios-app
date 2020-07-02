import CallKit
import AVFoundation

class NativeCallInterface: NSObject {
    
    private let provider: CXProvider
    private let callController: CXCallController
    
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
        self.callController = CXCallController(queue: service.queue)
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
    
    func reportIncomingCall(uuid: UUID, handleId: String, localizedName: String, completion: @escaping CallInterfaceCompletion) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: handleId)
        update.localizedCallerName = localizedName
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
    
    func requestStartCall(uuid: UUID, handle: CXHandle, playOutgoingRingtone: Bool, completion: @escaping CallInterfaceCompletion) {
        let action = CXStartCallAction(call: uuid, handle: handle)
        callController.requestTransaction(with: action) { (error) in
            completion(error)
            if error == nil {
                let update = CXCallUpdate()
                if let call = self.service.activeCall as? PeerToPeerCall, call.remoteUserId == handle.value {
                    update.localizedCallerName = call.remoteUsername
                } else if let call = self.service.activeCall as? GroupCall, call.conversationId == handle.value {
                    update.localizedCallerName = call.conversationName
                }
                update.supportsHolding = false
                update.supportsGrouping = false
                update.supportsUngrouping = false
                update.supportsDTMF = false
                update.hasVideo = false
                self.provider.reportCall(with: uuid, updated: update)
            }
        }
    }
    
    func requestAnswerCall(uuid: UUID) {
        assertionFailure("This is not expected to happen")
    }
    
    func requestEndCall(uuid: UUID, completion: @escaping CallInterfaceCompletion) {
        // TODO: This not expected to happen?
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
        if let call = call as? PeerToPeerCall {
            reportIncomingCall(uuid: call.uuid,
                               handleId: call.remoteUserId,
                               localizedName: call.remoteUsername,
                               completion: completion)
        } else if let call = call as? GroupCall {
            reportIncomingCall(uuid: call.uuid,
                               handleId: call.conversationId,
                               localizedName: call.conversationName,
                               completion: completion)
        }
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
        service.startCall(uuid: action.callUUID, handle: action.handle) { (success) in
            success ? action.fulfill() : action.fail()
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        let uuid = action.callUUID
        if service.hasPendingSDP(for: uuid) || service.hasPendingAnswerGroupCall(with: uuid) {
            unansweredIncomingCallUUIDs.remove(uuid)
            service.answerCall(uuid: uuid) { (success) in
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
        unansweredIncomingCallUUIDs.remove(action.callUUID)
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
        if let call = service.activeCall as? PeerToPeerCall, call.isOutgoing, !call.hasReceivedRemoteAnswer {
            service.ringtonePlayer.play(ringtone: .outgoing)
        }
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        
    }
    
}
