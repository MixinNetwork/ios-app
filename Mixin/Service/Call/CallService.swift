import Foundation
import PushKit
import WebRTC
import MixinServices

class CallService: NSObject {
    
    static let shared = CallService()
    static let mutenessDidChangeNotification = Notification.Name("one.mixin.messenger.call-service.muteness-did-change")

    let queue = DispatchQueue(label: "one.mixin.messenger.call-manager")
    
    var isMuted = false {
        didSet {
            NotificationCenter.default.postOnMain(name: Self.mutenessDidChangeNotification)
            if let audioTrack = rtcClient.audioTrack {
                audioTrack.isEnabled = !isMuted
                Logger.write(log: "[Call] isMuted: \(isMuted)")
            } else {
                Logger.write(log: "[Call] isMuted: \(isMuted), finds no audio track")
            }
        }
    }
    
    var usesSpeaker = false {
        didSet {
            updateAudioSessionConfiguration()
            Logger.write(log: "[Call] usesSpeaker: \(usesSpeaker)")
        }
    }
    
    var hasActiveOrPendingCall: Bool {
        queue.sync {
            activeCall != nil || !pendingCalls.isEmpty
        }
    }
    
    private(set) lazy var ringtonePlayer = RingtonePlayer()
    
    private(set) var activeCall: Call? // Access from CallService.queue
    private(set) var handledUUIDs = Set<UUID>() // Access from main queue
    
    private let queueSpecificKey = DispatchSpecificKey<Void>()
    private let listPendingCallDelay = DispatchTimeInterval.seconds(2)
    
    private lazy var rtcClient = WebRTCClient()
    private lazy var nativeCallInterface = NativeCallInterface(service: self)
    private lazy var mixinCallInterface = MixinCallInterface(service: self)
    
    private var usesCallKit = false // Access from CallService.queue
    private var pushRegistry: PKPushRegistry?
    private var window: CallWindow?
    private var viewController: CallViewController?
    private var pendingCalls = [UUID: Call]()
    private var pendingSDPs = [UUID: RTCSessionDescription]()
    private var pendingCandidates = [UUID: [RTCIceCandidate]]()
    private var listPendingCallWorkItems = [UUID: DispatchWorkItem]()
    
    private weak var unansweredTimer: Timer?
    
    // Access from CallService.queue
    private var callInterface: CallInterface {
        if usesCallKit {
            Logger.write(log: "[Call] using native call interface")
        } else {
            Logger.write(log: "[Call] using mixin call interface")
        }
        return usesCallKit ? nativeCallInterface : mixinCallInterface
    }
    
    override init() {
        super.init()
        queue.setSpecific(key: queueSpecificKey, value: ())
        rtcClient.delegate = self
        updateCallKitAvailability()
    }
    
    func showCallingInterface(userId: String, username: String, style: CallViewController.Style) {
        showCallingInterface(style: style) { (viewController) in
            viewController.reload(userId: userId, username: username)
        }
    }
    
    func showCallingInterface(user: UserItem, style: CallViewController.Style) {
        showCallingInterface(style: style) { (viewController) in
            viewController.reload(user: user)
        }
    }
    
    func dismissCallingInterface() {
        AppDelegate.current.mainWindow.makeKeyAndVisible()
        viewController?.disableConnectionDurationTimer()
        viewController = nil
        window = nil
        Logger.write(log: "[Call] calling interface dismissed")
    }
    
    func registerForPushKitNotificationsIfAvailable() {
        dispatch {
            guard self.pushRegistry == nil else {
                return
            }
            guard self.usesCallKit else {
                AccountAPI.shared.updateSession(voipToken: voipTokenRemove)
                Logger.write(log: "[Call] voip token removed because usesCallKit says false")
                return
            }
            let registry = PKPushRegistry(queue: self.queue)
            registry.desiredPushTypes = [.voIP]
            registry.delegate = self
            if let token = registry.pushToken(for: .voIP)?.toHexString() {
                Logger.write(log: "[Call] voip token registered with locally cached")
                AccountAPI.shared.updateSession(voipToken: token)
            }
            self.pushRegistry = registry
        }
    }
    
    func hasPendingSDP(for uuid: UUID) -> Bool {
        pendingSDPs[uuid] != nil
    }
    
}

// MARK: - PKPushRegistryDelegate
extension CallService: PKPushRegistryDelegate {
    
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        guard LoginManager.shared.isLoggedIn else {
            return
        }
        let token = pushCredentials.token.toHexString()
        AccountAPI.shared.updateSession(voipToken: token)
        Logger.write(log: "[Call] voip token registered with new updated")
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        guard LoginManager.shared.isLoggedIn, !AppGroupUserDefaults.User.needsUpgradeInMainApp else {
            nativeCallInterface.reportImmediateFailureCall()
            completion()
            Logger.write(log: "[Call] PushKit handler failed because user is logged out or needs upgrade")
            return
        }
        guard let messageId = payload.dictionaryPayload["message_id"] as? String, let uuid = UUID(uuidString: messageId) else {
            nativeCallInterface.reportImmediateFailureCall()
            Logger.write(log: "[Call] PushKit payload lacks of a valid message id")
            completion()
            return
        }
        guard let userId = payload.dictionaryPayload["user_id"] as? String, let username = payload.dictionaryPayload["full_name"] as? String else {
            nativeCallInterface.reportImmediateFailureCall()
            Logger.write(log: "[Call] PushKit payload lacks of user ID or username")
            completion()
            return
        }
        DispatchQueue.main.async {
            self.beginAutoCancellingBackgroundTaskIfNotActive()
            MixinService.isStopProcessMessages = false
            WebSocketService.shared.connectIfNeeded()
            Logger.write(log: "[Call] WS started connecting by PushKit handler")
        }
        if usesCallKit && !MessageDAO.shared.isExist(messageId: messageId) {
            let call = Call(uuid: uuid, opponentUserId: userId, opponentUsername: username, isOutgoing: false)
            pendingCalls[uuid] = call
            nativeCallInterface.reportIncomingCall(uuid: uuid, userId: userId, username: username) { (error) in
                completion()
            }
            Logger.write(log: "[Call] Call reported by PushKit handler \(call.debugDescription)")
        } else {
            Logger.write(log: "[Call] Call reported a failure by PushKit handler. usesCallKit: \(usesCallKit)")
            nativeCallInterface.reportImmediateFailureCall()
            completion()
        }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP, registry.pushToken(for: .voIP) == nil else {
            return
        }
        Logger.write(log: "[Call] voip token removed because of invalidation")
        AccountAPI.shared.updateSession(voipToken: voipTokenRemove)
    }
    
}

// MARK: - Interface
extension CallService {
    
    func handlePendingWebRTCJobs() {
        dispatch {
            let jobs = JobDAO.shared.nextBatchJobs(category: .Task, action: .PENDING_WEBRTC, limit: nil)
            Logger.write(log: "[Call] wakes up \(jobs.count) pending WebRTC jobs")
            for job in jobs {
                let data = job.toBlazeMessageData()
                let isOffer = data.category == MessageCategory.WEBRTC_AUDIO_OFFER.rawValue
                let isTimedOut = abs(data.createdAt.toUTCDate().timeIntervalSinceNow) >= callTimeoutInterval
                if isOffer && isTimedOut {
                    Logger.write(log: "[Call] inserted timed out offer: \(data.messageId) from pending WebRTC job")
                    let msg = Message.createWebRTCMessage(messageId: data.messageId,
                                                          conversationId: data.conversationId,
                                                          userId: data.userId,
                                                          category: .WEBRTC_AUDIO_CANCEL,
                                                          mediaDuration: 0,
                                                          status: .DELIVERED)
                    MessageDAO.shared.insertMessage(message: msg, messageSource: "")
                } else if !isOffer || !MessageDAO.shared.isExist(messageId: data.messageId) {
                    Logger.write(log: "[Call] dispatched pending WebRTC blaze message with id: \(data.messageId), quote: \(data.quoteMessageId), category: \(data.category)")
                    self.handleIncomingBlazeMessageData(data)
                } else {
                    Logger.write(log: "[Call] dropped pending WebRTC blaze message with id: \(data.messageId), quote: \(data.quoteMessageId), category: \(data.category)")
                }
                JobDAO.shared.removeJob(jobId: job.jobId)
            }
        }
    }
    
    func requestStartCall(opponentUser: UserItem) {
        
        func performRequest() {
            updateCallKitAvailability()
            registerForPushKitNotificationsIfAvailable()
            let uuid = UUID()
            activeCall = Call(uuid: uuid, opponentUser: opponentUser, isOutgoing: true)
            let handle = CallHandle(id: opponentUser.userId, name: opponentUser.fullName)
            Logger.write(log: "[Call] service request start call: \(activeCall!.debugDescription)")
            callInterface.requestStartCall(uuid: uuid, handle: handle) { (error) in
                let errDesc = error?.localizedDescription ?? "null"
                Logger.write(log: "[Call] interface reported call: \(uuid.uuidString) started with error: \(errDesc)")
                if let error = error as? CallError {
                    self.alert(error: error)
                } else if let error = error {
                    reporter.report(error: error)
                    showAutoHiddenHud(style: .error, text: R.string.localizable.chat_message_call_failed())
                }
            }
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { (isGranted) in
            if isGranted {
                self.dispatch(performRequest)
            } else {
                DispatchQueue.main.async {
                    Logger.write(log: "[Call] service start call failed for microphone permission denied")
                    self.alert(error: .microphonePermissionDenied)
                }
            }
        }
        
    }
    
    func requestEndCall() {
        dispatch {
            guard let uuid = self.activeCall?.uuid ?? self.pendingCalls.first?.key else {
                Logger.write(log: "[Call] service is requested to end call but finds nothing")
                return
            }
            Logger.write(log: "[Call] service is requested to end call")
            self.callInterface.requestEndCall(uuid: uuid) { (error) in
                if let error = error {
                    // Don't think we would get error here
                    Logger.write(log: "[Call] service failed to request interface to end call with error: \(error.localizedDescription)")
                    reporter.report(error: error)
                    self.endCall(uuid: uuid)
                }
            }
        }
    }
    
    func requestAnswerCall() {
        dispatch {
            guard let uuid = self.pendingCalls.first?.key else {
                Logger.write(log: "[Call] service is requested to answer call but finds nothing")
                return
            }
            Logger.write(log: "[Call] service is requested to answer call")
            self.callInterface.requestAnswerCall(uuid: uuid)
        }
    }
    
    func requestSetMute(_ muted: Bool) {
        dispatch {
            guard let uuid = self.activeCall?.uuid else {
                Logger.write(log: "[Call] service is requested set mute but finds no active call")
                return
            }
            Logger.write(log: "[Call] service is requested set mute")
            self.callInterface.requestSetMute(uuid: uuid, muted: muted) { (error) in
                if let error = error {
                    Logger.write(log: "[Call] service failed to request interface to set mute with error: \(error.localizedDescription)")
                    reporter.report(error: error)
                }
            }
        }
    }
    
    func alert(error: CallError) {
        let content = error.alertContent
        DispatchQueue.main.async {
            if case .microphonePermissionDenied = error {
                Logger.write(log: "[Call] service presented microphone permission alert")
                AppDelegate.current.mainWindow.rootViewController?.alertSettings(content)
            } else {
                Logger.write(log: "[Call] service presented alert: \(content)")
                AppDelegate.current.mainWindow.rootViewController?.alert(content)
            }
        }
    }
    
}

// MARK: - Callback
extension CallService {
    
    func startCall(uuid: UUID, handle: CallHandle, completion: ((Bool) -> Void)?) {
        AudioManager.shared.pause()
        dispatch {
            guard let call = self.activeCall, call.opponentUserId == handle.id else {
                self.alert(error: .inconsistentCallStarted)
                completion?(false)
                Logger.write(log: "[Call] service start call: \(uuid) fails for inconsistent call. ActiveCall: \(self.activeCall?.debugDescription ?? "null"), handle: \(handle.debugDescription)")
                return
            }
            guard let opponentUser = call.opponentUser ?? UserDAO.shared.getUser(userId: handle.id) else {
                self.alert(error: .missingUser(userId: handle.id))
                completion?(false)
                Logger.write(log: "[Call] service start call: \(uuid) fails for missing user")
                return
            }
            guard WebSocketService.shared.isConnected else {
                self.alert(error: .networkFailure)
                completion?(false)
                Logger.write(log: "[Call] service start call: \(uuid) fails for not connected")
                return
            }
            DispatchQueue.main.sync {
                self.showCallingInterface(user: opponentUser, style: .outgoing)
            }
            
            let timer = Timer(timeInterval: callTimeoutInterval,
                              target: self,
                              selector: #selector(self.unansweredTimeout),
                              userInfo: nil,
                              repeats: false)
            RunLoop.main.add(timer, forMode: .default)
            self.unansweredTimer = timer
            Logger.write(log: "[Call] unanswered timer: \(timer) started ticking")
            Logger.write(log: "[Call] generating offer for: \(uuid)")
            self.rtcClient.offer { (sdp, error) in
                guard let sdp = sdp else {
                    self.dispatch {
                        Logger.write(log: "[Call] call: \(uuid), no sdp is generated, error: \(error?.localizedDescription)")
                        self.failCurrentCall(sendFailedMessageToRemote: false,
                                             error: .sdpConstruction(error))
                        completion?(false)
                    }
                    return
                }
                guard let content = sdp.jsonString else {
                    self.dispatch {
                        Logger.write(log: "[Call] call: \(uuid), sdp cannot be serialized, error: \(error?.localizedDescription)")
                        self.failCurrentCall(sendFailedMessageToRemote: false,
                                             error: .sdpSerialization(error))
                        completion?(false)
                    }
                    return
                }
                let msg = Message.createWebRTCMessage(messageId: call.uuidString,
                                                      conversationId: call.conversationId,
                                                      category: .WEBRTC_AUDIO_OFFER,
                                                      content: content,
                                                      status: .SENDING)
                SendMessageService.shared.sendMessage(message: msg,
                                                      ownerUser: opponentUser,
                                                      isGroupMessage: false)
                Logger.write(log: "[Call] call: \(uuid), offer is sent")
                completion?(true)
            }
        }
    }
    
    func answerCall(uuid: UUID, completion: ((Bool) -> Void)?) {
        dispatch {
            guard let call = self.pendingCalls[uuid], let sdp = self.pendingSDPs[uuid] else {
                Logger.write(log: "[Call] service try to answer call: \(uuid) but finds nothing")
                return
            }
            self.pendingCalls.removeValue(forKey: uuid)
            self.pendingSDPs.removeValue(forKey: uuid)
            
            DispatchQueue.main.sync {
                if let opponentUser = call.opponentUser {
                    self.showCallingInterface(user: opponentUser,
                                              style: .connecting)
                } else {
                    self.showCallingInterface(userId: call.opponentUserId,
                                              username: call.opponentUsername,
                                              style: .connecting)
                }
            }
            self.activeCall = call
            Logger.write(log: "[Call] service ending all pending calls")
            for uuid in self.pendingCalls.keys {
                self.endCall(uuid: uuid)
            }
            self.ringtonePlayer.stop()
            self.rtcClient.set(remoteSdp: sdp) { (error) in
                if let error = error {
                    Logger.write(log: "[Call] call: \(uuid) set remote sdp failed with error: \(error.localizedDescription)")
                    self.dispatch {
                        self.failCurrentCall(sendFailedMessageToRemote: true,
                                             error: .setRemoteSdp(error))
                        completion?(false)
                    }
                } else {
                    Logger.write(log: "[Call] call: \(uuid) generating answer")
                    self.rtcClient.answer(completion: { (answer, error) in
                        self.dispatch {
                            guard let answer = answer, let content = answer.jsonString else {
                                Logger.write(log: "[Call] call: \(uuid) failed to construct answer")
                                self.failCurrentCall(sendFailedMessageToRemote: true,
                                                     error: .answerConstruction(error))
                                completion?(false)
                                return
                            }
                            let msg = Message.createWebRTCMessage(conversationId: call.conversationId,
                                                                  category: .WEBRTC_AUDIO_ANSWER,
                                                                  content: content,
                                                                  status: .SENDING,
                                                                  quoteMessageId: call.uuidString)
                            SendMessageService.shared.sendMessage(message: msg,
                                                                  ownerUser: call.opponentUser,
                                                                  isGroupMessage: false)
                            Logger.write(log: "[Call] call: \(uuid) answer is sent")
                            if let candidates = self.pendingCandidates.removeValue(forKey: uuid) {
                                Logger.write(log: "[Call] call: \(uuid) using \(candidates.count) pending candidates")
                                candidates.forEach(self.rtcClient.add(remoteCandidate:))
                            }
                            completion?(true)
                        }
                    })
                }
            }
        }
    }
    
    func endCall(uuid: UUID) {
        
        func sendEndMessage(call: Call, category: MessageCategory) {
            DispatchQueue.main.sync(execute: beginAutoCancellingBackgroundTaskIfNotActive)
            let msg = Message.createWebRTCMessage(conversationId: call.conversationId,
                                                  category: category,
                                                  status: .SENDING,
                                                  quoteMessageId: call.uuidString)
            SendMessageService.shared.sendWebRTCMessage(message: msg,
                                                        recipientId: call.opponentUserId)
            insertCallCompletedMessage(call: call,
                                       isUserInitiated: true,
                                       category: category)
        }
        
        dispatch {
            if let call = self.activeCall, call.uuid == uuid {
                Logger.write(log: "[Call] ending active call: \(uuid)")
                DispatchQueue.main.sync {
                    self.viewController?.style = .disconnecting
                }
                let category: MessageCategory
                if call.connectedDate != nil {
                    category = .WEBRTC_AUDIO_END
                } else if call.isOutgoing {
                    category = .WEBRTC_AUDIO_CANCEL
                } else {
                    category = .WEBRTC_AUDIO_DECLINE
                }
                sendEndMessage(call: call, category: category)
            } else if let call = self.pendingCalls[uuid] {
                Logger.write(log: "[Call] ending pending call: \(uuid)")
                sendEndMessage(call: call, category: .WEBRTC_AUDIO_DECLINE)
            } else {
                Logger.write(log: "[Call] try to end call: \(uuid), but finds nothing")
            }
            self.close(uuid: uuid)
        }
    }
    
    func closeAll() {
        Logger.write(log: "[Call] closing all calls")
        activeCall = nil
        rtcClient.close()
        unansweredTimer?.invalidate()
        pendingCalls = [:]
        pendingSDPs = [:]
        pendingCandidates = [:]
        ringtonePlayer.stop()
        performSynchronouslyOnMainThread {
            dismissCallingInterface()
        }
        isMuted = false
        usesSpeaker = false
        updateCallKitAvailability()
        registerForPushKitNotificationsIfAvailable()
    }
    
    func close(uuid: UUID) {
        Logger.write(log: "[Call] closing \(uuid)")
        if let call = activeCall, call.uuid == uuid {
            activeCall = nil
            rtcClient.close()
            Logger.write(log: "[Call] closing active call: \(uuid)")
            if call.isOutgoing {
                unansweredTimer?.invalidate()
                Logger.write(log: "[Call] unansweredTimer invalidated")
            }
        }
        pendingCalls.removeValue(forKey: uuid)
        pendingSDPs.removeValue(forKey: uuid)
        pendingCandidates.removeValue(forKey: uuid)
        if pendingCalls.isEmpty && activeCall == nil {
            Logger.write(log: "[Call] No calls after closing. do some cleaning")
            ringtonePlayer.stop()
            performSynchronouslyOnMainThread {
                dismissCallingInterface()
            }
            isMuted = false
            usesSpeaker = false
            updateCallKitAvailability()
            registerForPushKitNotificationsIfAvailable()
        }
    }
    
}

// MARK: - CallMessageCoordinator
extension CallService: CallMessageCoordinator {
    
    func shouldSendRtcBlazeMessage(with category: MessageCategory) -> Bool {
        let onlySendIfThereIsAnActiveCall = [.WEBRTC_AUDIO_OFFER, .WEBRTC_AUDIO_ANSWER, .WEBRTC_ICE_CANDIDATE].contains(category)
        return activeCall != nil || !onlySendIfThereIsAnActiveCall
    }
    
    func handleIncomingBlazeMessageData(_ data: BlazeMessageData) {
        
        func hasCall(uuid: UUID) -> Bool {
            activeCall?.uuid == uuid || pendingCalls[uuid] != nil
        }
        
        func handle(data: BlazeMessageData) {
            switch data.category {
            case MessageCategory.WEBRTC_AUDIO_OFFER.rawValue:
                Logger.write(log: "[Call] Got offer: \(data.messageId)")
                self.handleOffer(data: data)
            case MessageCategory.WEBRTC_ICE_CANDIDATE.rawValue:
                Logger.write(log: "[Call] Got candidate quoting: \(data.quoteMessageId)")
                self.handleIceCandidate(data: data)
            default:
                Logger.write(log: "[Call] Got message quoting: \(data.quoteMessageId), category: \(data.category)")
                self.handleCallStatusChange(data: data)
            }
        }
        
        dispatch {
            if data.source != BlazeMessageAction.listPendingMessages.rawValue {
                handle(data: data)
            } else {
                let isOffer = data.category == MessageCategory.WEBRTC_AUDIO_OFFER.rawValue
                if isOffer, let uuid = UUID(uuidString: data.messageId), !hasCall(uuid: uuid) {
                    if abs(data.createdAt.toUTCDate().timeIntervalSinceNow) >= callTimeoutInterval {
                        let msg = Message.createWebRTCMessage(data: data, category: .WEBRTC_AUDIO_CANCEL, status: .DELIVERED)
                        MessageDAO.shared.insertMessage(message: msg, messageSource: data.source)
                        Logger.write(log: "[Call] inserted a timed out list pending offer: \(uuid)")
                    } else {
                        let workItem = DispatchWorkItem(block: {
                            handle(data: data)
                            self.listPendingCallWorkItems.removeValue(forKey: uuid)
                        })
                        self.listPendingCallWorkItems[uuid] = workItem
                        self.queue.asyncAfter(deadline: .now() + self.listPendingCallDelay, execute: workItem)
                        Logger.write(log: "[Call] put list pending offer: \(uuid) into pending queue")
                    }
                } else if !isOffer, let uuid = UUID(uuidString: data.quoteMessageId), let workItem = self.listPendingCallWorkItems[uuid], !hasCall(uuid: uuid), let category = MessageCategory(rawValue: data.category), MessageCategory.endCallCategories.contains(category) {
                    workItem.cancel()
                    self.listPendingCallWorkItems.removeValue(forKey: uuid)
                    self.pendingCandidates.removeValue(forKey: uuid)
                    let msg = Message.createWebRTCMessage(messageId: data.quoteMessageId,
                                                          conversationId: data.conversationId,
                                                          userId: data.userId,
                                                          category: category,
                                                          status: .DELIVERED)
                    MessageDAO.shared.insertMessage(message: msg, messageSource: data.source)
                    Logger.write(log: "[Call] got end message: \(category.rawValue) for list pending offer: \(uuid)")
                } else {
                    handle(data: data)
                }
            }
        }
        
    }
    
}

// MARK: - Blaze message data handlers
extension CallService {
    
    private func handleOffer(data: BlazeMessageData) {
        guard !MessageDAO.shared.isExist(messageId: data.messageId) else {
            Logger.write(log: "[Call] offer: \(data.messageId) dropped for already existed")
            return
        }
        
        func handle(error: Error, username: String?) {
            
            func declineOffer(data: BlazeMessageData, category: MessageCategory) {
                Logger.write(log: "[Call] offer: \(data) declined for: \(error.localizedDescription)")
                let offer = Message.createWebRTCMessage(data: data, category: category, status: .DELIVERED)
                MessageDAO.shared.insertMessage(message: offer, messageSource: "")
                let reply = Message.createWebRTCMessage(quote: data, category: category, status: .SENDING)
                SendMessageService.shared.sendWebRTCMessage(message: reply, recipientId: data.getSenderId())
                if let uuid = UUID(uuidString: data.messageId) {
                    close(uuid: uuid)
                }
            }
            
            dispatch {
                switch error {
                case CallError.busy:
                    declineOffer(data: data, category: .WEBRTC_AUDIO_BUSY)
                case CallError.microphonePermissionDenied:
                    declineOffer(data: data, category: .WEBRTC_AUDIO_DECLINE)
                    DispatchQueue.main.sync {
                        self.alert(error: .microphonePermissionDenied)
                        if UIApplication.shared.applicationState != .active {
                            NotificationManager.shared.requestDeclinedCallNotification(username: username, messageId: data.messageId)
                        }
                    }
                default:
                    declineOffer(data: data, category: .WEBRTC_AUDIO_FAILED)
                }
            }
        }
        
        do {
            DispatchQueue.main.sync(execute: beginAutoCancellingBackgroundTaskIfNotActive)
            guard let user = UserDAO.shared.getUser(userId: data.userId) else {
                handle(error: CallError.missingUser(userId: data.userId), username: nil)
                Logger.write(log: "[Call] missing user for offer: \(data.messageId)")
                return
            }
            guard let uuid = UUID(uuidString: data.messageId) else {
                handle(error: CallError.invalidUUID(uuid: data.messageId), username: user.fullName)
                Logger.write(log: "[Call] invalid UUID for offer: \(data.messageId)")
                return
            }
            DispatchQueue.main.async {
                self.handledUUIDs.insert(uuid)
            }
            guard let sdpString = data.data.base64Decoded(), let sdp = RTCSessionDescription(jsonString: sdpString) else {
                handle(error: CallError.invalidSdp(sdp: data.data), username: user.fullName)
                Logger.write(log: "[Call] invalid sdp for offer: \(data.messageId)")
                return
            }
            AudioManager.shared.pause()
            let call = Call(uuid: uuid, opponentUser: user, isOutgoing: false)
            pendingCalls[uuid] = call
            pendingSDPs[uuid] = sdp
            
            Logger.write(log: "[Call] call: \(uuid) has reported to interface")
            callInterface.reportIncomingCall(call) { (error) in
                if let error = error {
                    handle(error: error, username: user.fullName)
                }
            }
        }
    }
    
    private func handleIceCandidate(data: BlazeMessageData) {
        guard let candidatesString = data.data.base64Decoded() else {
            return
        }
        let newCandidates = [RTCIceCandidate](jsonString: candidatesString)
        if let call = activeCall, data.quoteMessageId == call.uuidString, rtcClient.canAddRemoteCandidate {
            Logger.write(log: "[Call] candidate: \(data.messageId) is added to rtc client")
            newCandidates.forEach(rtcClient.add(remoteCandidate:))
        } else if let uuid = UUID(uuidString: data.quoteMessageId) {
            var candidates = pendingCandidates[uuid] ?? []
            candidates.append(contentsOf: newCandidates)
            pendingCandidates[uuid] = candidates
            Logger.write(log: "[Call] candidate: \(data.messageId) is added to pending pool")
        }
    }
    
    private func handleCallStatusChange(data: BlazeMessageData) {
        guard let uuid = UUID(uuidString: data.quoteMessageId) else {
            return
        }
        if let call = activeCall, uuid == call.uuid, call.isOutgoing, data.category == MessageCategory.WEBRTC_AUDIO_ANSWER.rawValue, let sdpString = data.data.base64Decoded(), let sdp = RTCSessionDescription(jsonString: sdpString) {
            Logger.write(log: "[Call] Got answer for call: \(uuid)")
            callInterface.reportOutgoingCallStartedConnecting(uuid: uuid)
            call.hasReceivedRemoteAnswer = true
            unansweredTimer?.invalidate()
            Logger.write(log: "[Call] unansweredTimer invalidated")
            ringtonePlayer.stop()
            DispatchQueue.main.sync {
                viewController?.style = .connecting
            }
            rtcClient.set(remoteSdp: sdp) { (error) in
                if let error = error {
                    self.dispatch {
                        Logger.write(log: "[Call] Failed to set remote sdp with error: \(error.localizedDescription), when answering call: \(uuid)")
                        self.failCurrentCall(sendFailedMessageToRemote: true,
                                             error: .setRemoteAnswer(error))
                        self.callInterface.reportCall(uuid: uuid,
                                                      endedByReason: .failed)
                    }
                }
            }
        } else if let category = MessageCategory(rawValue: data.category), MessageCategory.endCallCategories.contains(category) {
            if let call = activeCall ?? pendingCalls[uuid], call.uuid == uuid {
                Logger.write(log: "[Call] Got \(category.rawValue) for call: \(uuid)")
                DispatchQueue.main.sync {
                    viewController?.style = .disconnecting
                }
                insertCallCompletedMessage(call: call, isUserInitiated: false, category: category)
            } else {
                // When a call is pushed via APN User Notifications and gets cancelled before app is launched
                // This routine may execute when app is launched manually, sometimes before pending WebRTC jobs are awake
                let msg = Message.createWebRTCMessage(messageId: data.quoteMessageId,
                                                      conversationId: data.conversationId,
                                                      userId: data.userId,
                                                      category: category,
                                                      status: .DELIVERED)
                MessageDAO.shared.insertMessage(message: msg, messageSource: "")
                Logger.write(log: "[Call] APN Fix: msg inserted with id \(msg.messageId)")
            }
            callInterface.reportCall(uuid: uuid, endedByReason: .remoteEnded)
            close(uuid: uuid)
        } else {
            Logger.write(log: "[Call] Got useless message: \(data.messageId), quoting: \(data.quoteMessageId), category: \(data.category)")
        }
    }
    
    private func insertCallCompletedMessage(call: Call, isUserInitiated: Bool, category: MessageCategory) {
        let timeIntervalSinceNow = call.connectedDate?.timeIntervalSinceNow ?? 0
        let duration = abs(timeIntervalSinceNow * millisecondsPerSecond)
        let shouldMarkMessageRead = call.isOutgoing
            || category == .WEBRTC_AUDIO_END
            || (category == .WEBRTC_AUDIO_DECLINE && isUserInitiated)
        let status: MessageStatus = shouldMarkMessageRead ? .READ : .DELIVERED
        let msg = Message.createWebRTCMessage(messageId: call.uuidString,
                                              conversationId: call.conversationId,
                                              userId: call.raisedByUserId,
                                              category: category,
                                              mediaDuration: Int64(duration),
                                              status: status)
        MessageDAO.shared.insertMessage(message: msg, messageSource: "")
    }
    
}

// MARK: - WebRTCClientDelegate
extension CallService: WebRTCClientDelegate {
    
    func webRTCClient(_ client: WebRTCClient, didGenerateLocalCandidate candidate: RTCIceCandidate) {
        guard let call = activeCall, let content = [candidate].jsonString else {
            return
        }
        let msg = Message.createWebRTCMessage(conversationId: call.conversationId,
                                              category: .WEBRTC_ICE_CANDIDATE,
                                              content: content,
                                              status: .SENDING,
                                              quoteMessageId: call.uuidString)
        SendMessageService.shared.sendMessage(message: msg,
                                              ownerUser: call.opponentUser,
                                              isGroupMessage: false)
        Logger.write(log: "[Call] Sent candidate: \(msg.messageId)")
    }
    
    func webRTCClientDidConnected(_ client: WebRTCClient) {
        dispatch {
            guard let call = self.activeCall, call.connectedDate == nil else {
                return
            }
            let date = Date()
            call.connectedDate = date
            Logger.write(log: "[Call] Report call: \(call.debugDescription) is connected")
            if call.isOutgoing {
                self.callInterface.reportOutgoingCall(uuid: call.uuid, connectedAtDate: date)
            } else {
                self.callInterface.reportIncomingCall(uuid: call.uuid, connectedAtDate: date)
            }
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            DispatchQueue.main.sync {
                self.viewController?.style = .connected
            }
        }
        updateAudioSessionConfiguration()
    }
    
    func webRTCClientDidFailed(_ client: WebRTCClient) {
        dispatch {
            self.failCurrentCall(sendFailedMessageToRemote: true, error: .clientFailure)
            Logger.write(log: "[Call] WebRTC cliend failed")
        }
    }
    
}

// MARK: - Private works
extension CallService {
    
    @objc private func unansweredTimeout() {
        guard let call = activeCall, call.isOutgoing, !call.hasReceivedRemoteAnswer else {
            return
        }
        Logger.write(log: "[Call] Call: \(call.uuidString) is timed out")
        dismissCallingInterface()
        rtcClient.close()
        isMuted = false
        dispatch {
            self.ringtonePlayer.stop()
            let msg = Message.createWebRTCMessage(conversationId: call.conversationId,
                                                  category: .WEBRTC_AUDIO_CANCEL,
                                                  status: .SENDING,
                                                  quoteMessageId: call.uuidString)
            SendMessageService.shared.sendWebRTCMessage(message: msg, recipientId: call.opponentUserId)
            self.insertCallCompletedMessage(call: call, isUserInitiated: false, category: .WEBRTC_AUDIO_CANCEL)
            self.activeCall = nil
            self.callInterface.reportCall(uuid: call.uuid, endedByReason: .unanswered)
        }
    }
    
    private func dispatch(_ closure: @escaping () -> Void) {
        if DispatchQueue.getSpecific(key: queueSpecificKey) == nil {
            queue.async(execute: closure)
        } else {
            closure()
        }
    }
    
    private func updateCallKitAvailability() {
        usesCallKit = AVAudioSession.sharedInstance().recordPermission == .granted
        Logger.write(log: "[Call] CallKit: \(usesCallKit)")
    }
    
    private func showCallingInterface(style: CallViewController.Style, userRenderer renderUser: (CallViewController) -> Void) {
        
        Logger.write(log: "[Call] showing calling interface")

        func makeViewController() -> CallViewController {
            let viewController = CallViewController()
            viewController.service = self
            viewController.loadViewIfNeeded()
            self.viewController = viewController
            return viewController
        }
        
        let animated = self.window != nil
        
        let viewController = self.viewController ?? makeViewController()
        renderUser(viewController)
        
        let window = self.window ?? CallWindow(frame: UIScreen.main.bounds, root: viewController)
        window.makeKeyAndVisible()
        self.window = window
        
        UIView.performWithoutAnimation(viewController.view.layoutIfNeeded)
        
        let updateInterface = {
            viewController.style = style
            viewController.view.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: 0.3, animations: updateInterface)
        } else {
            UIView.performWithoutAnimation(updateInterface)
        }
    }
    
    private func failCurrentCall(sendFailedMessageToRemote: Bool, error: CallError) {
        guard let call = activeCall else {
            Logger.write(log: "[Call] service tries to fail current call with error: \(error.localizedDescription), but finds no active call")
            return
        }
        if sendFailedMessageToRemote {
            Logger.write(log: "[Call] sendFailedMessageToRemote call: \(call.uuidString)")
            let msg = Message.createWebRTCMessage(conversationId: call.conversationId,
                                                  category: .WEBRTC_AUDIO_FAILED,
                                                  status: .SENDING,
                                                  quoteMessageId: call.uuidString)
            SendMessageService.shared.sendMessage(message: msg,
                                                  ownerUser: call.opponentUser,
                                                  isGroupMessage: false)
        }
        Logger.write(log: "[Call] failing current call: \(call.uuidString)")
        let failedMessage = Message.createWebRTCMessage(messageId: call.uuidString,
                                                        conversationId: call.conversationId,
                                                        category: .WEBRTC_AUDIO_FAILED,
                                                        status: .DELIVERED)
        MessageDAO.shared.insertMessage(message: failedMessage, messageSource: "")
        close(uuid: call.uuid)
        reporter.report(error: error)
    }
    
    private func updateAudioSessionConfiguration() {
        let session = RTCAudioSession.sharedInstance()
        let category = AVAudioSession.Category.playAndRecord.rawValue
        let options: AVAudioSession.CategoryOptions = {
            var options: AVAudioSession.CategoryOptions = [.allowBluetooth]
            if self.usesSpeaker {
                options.insert(.defaultToSpeaker)
            }
            return options
        }()
        
        // https://stackoverflow.com/questions/49170274/callkit-loudspeaker-bug-how-whatsapp-fixed-it
        // DO NOT use the mode of voiceChat, or the speaker button in system
        // calling interface will soon becomes off after turning on
        let mode = AVAudioSession.Mode.default.rawValue
        
        let audioPort: AVAudioSession.PortOverride = self.usesSpeaker ? .speaker : .none
        
        let config = RTCAudioSessionConfiguration()
        config.category = category
        config.categoryOptions = options
        config.mode = mode
        RTCAudioSessionConfiguration.setWebRTC(config)
        
        RTCDispatcher.dispatchAsync(on: .typeAudioSession) {
            session.lockForConfiguration()
            do {
                try session.setCategory(category, with: options)
                try session.setMode(mode)
                try session.overrideOutputAudioPort(audioPort)
            } catch {
                reporter.report(error: error)
            }
            session.unlockForConfiguration()
        }
    }
    
    private func beginAutoCancellingBackgroundTaskIfNotActive() {
        guard UIApplication.shared.applicationState != .active else {
            return
        }
        var identifier: UIBackgroundTaskIdentifier = .invalid
        var cancelBackgroundTask: DispatchWorkItem!
        cancelBackgroundTask = DispatchWorkItem {
            if identifier != .invalid {
                UIApplication.shared.endBackgroundTask(identifier)
            }
            if let task = cancelBackgroundTask {
                task.cancel()
            }
        }
        identifier = UIApplication.shared.beginBackgroundTask {
            cancelBackgroundTask.perform()
        }
        let duration = max(10, min(29, UIApplication.shared.backgroundTimeRemaining - 1))
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: cancelBackgroundTask)
    }
    
}
