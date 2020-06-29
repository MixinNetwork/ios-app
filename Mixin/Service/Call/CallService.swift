import Foundation
import PushKit
import CallKit
import WebRTC
import MixinServices

class CallService: NSObject {
    
    static let shared = CallService()
    static let mutenessDidChangeNotification = Notification.Name("one.mixin.messenger.CallService.MutenessDidChange")
    static let didReceivePublishingWithoutActiveGroupCall = Notification.Name("one.mixin.messenger.CallService.DidReceivePublishingWithoutActiveGroupCall")
    static let conversationIdUserInfoKey = "conv_id"
    
    let queue = DispatchQueue(label: "one.mixin.messenger.CallService")
    
    var isMuted = false {
        didSet {
            NotificationCenter.default.postOnMain(name: Self.mutenessDidChangeNotification)
            if let audioTrack = rtcClient.audioTrack {
                audioTrack.isEnabled = !isMuted
            }
        }
    }
    
    var usesSpeaker = false {
        didSet {
            updateAudioSessionConfiguration()
        }
    }
    
    var hasCall: Bool {
        queue.sync {
            activeCall != nil || !pendingAnswerCalls.isEmpty
        }
    }
    
    var connectionDuration: String? {
        guard let connectedDate = activeCall?.connectedDate else {
            return nil
        }
        let duration = abs(connectedDate.timeIntervalSinceNow)
        return mediaDurationFormatter.string(from: duration)
    }
    
    private(set) lazy var ringtonePlayer = RingtonePlayer()
    
    private(set) var activeCall: Call? // Access from CallService.queue
    private(set) var handledUUIDs = Set<UUID>() // Access from main queue
    private(set) var isMinimized = false
    
    private let queueSpecificKey = DispatchSpecificKey<Void>()
    private let listPendingCallDelay = DispatchTimeInterval.seconds(2)
    
    private lazy var rtcClient = WebRTCClient(delegateQueue: queue)
    private lazy var nativeCallInterface = NativeCallInterface(service: self)
    private lazy var mixinCallInterface = MixinCallInterface(service: self)
    
    private var usesCallKit = false // Access from CallService.queue
    private var pushRegistry: PKPushRegistry?
    
    private var pendingAnswerCalls = [UUID: Call]()
    private var pendingSDPs = [UUID: RTCSessionDescription]()
    private var pendingCandidates = [UUID: [RTCIceCandidate]]()
    private var pendingTrickles = [UUID: [String]]() // Key is Call's UUID, Value is array of candidate string
    private var listPendingCallWorkItems = [UUID: DispatchWorkItem]()
    private var inGroupCallUserIds = [String: [String]]() // Key is conversation ID, value is set of user IDs
    private var krakenListPollingTimers = NSMapTable<NSString, Timer>(keyOptions: .copyIn, valueOptions: .weakMemory)
    
    private var window: CallWindow?
    private var viewController: CallViewController?
    
    private weak var unansweredTimer: Timer?
    
    // Access from CallService.queue
    private var callInterface: CallInterface {
        usesCallKit ? nativeCallInterface : mixinCallInterface
    }
    
    override init() {
        super.init()
        queue.setSpecific(key: queueSpecificKey, value: ())
        rtcClient.delegate = self
        updateCallKitAvailability()
    }
    
    func showJoinGroupCallConfirmation(inCallUserIds ids: [String]) {
        let controller = GroupCallConfirmationViewController(service: self)
        controller.loadMembers(with: ids)
        
        let window = self.window ?? CallWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window
        
        UIView.performWithoutAnimation(controller.view.layoutIfNeeded)
    }
    
    func dismissCallingInterface() {
        AppDelegate.current.mainWindow.makeKeyAndVisible()
        if let container = UIApplication.homeContainerViewController {
            container.minimizedCallViewControllerIfLoaded?.view.alpha = 0
        }
        viewController?.disableConnectionDurationTimer()
        viewController = nil
        window = nil
    }
    
    func registerForPushKitNotificationsIfAvailable() {
        dispatch {
            guard self.pushRegistry == nil else {
                return
            }
            guard self.usesCallKit else {
                AccountAPI.shared.updateSession(voipToken: voipTokenRemove)
                return
            }
            let registry = PKPushRegistry(queue: self.queue)
            registry.desiredPushTypes = [.voIP]
            registry.delegate = self
            if let token = registry.pushToken(for: .voIP)?.toHexString() {
                AccountAPI.shared.updateSession(voipToken: token)
            }
            self.pushRegistry = registry
        }
    }
    
    func hasPendingSDP(for uuid: UUID) -> Bool {
        pendingSDPs[uuid] != nil
    }
    
    func showCallingInterface(call: Call) {
        
        func makeViewController() -> CallViewController {
            let viewController = CallViewController(service: self)
            viewController.loadViewIfNeeded()
            self.viewController = viewController
            return viewController
        }
        
        let animated = self.window != nil
        
        let viewController = self.viewController ?? makeViewController()
        let window = self.window ?? CallWindow(frame: UIScreen.main.bounds)
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        self.window = window
        
        UIView.performWithoutAnimation(viewController.view.layoutIfNeeded)
        
        let updateInterface = {
            viewController.reloadAndObserve(call: call)
            viewController.view.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: 0.3, animations: updateInterface)
        } else {
            UIView.performWithoutAnimation(updateInterface)
        }
    }
    
    func setInterfaceMinimized(_ minimized: Bool, animated: Bool) {
        guard let min = UIApplication.homeContainerViewController?.minimizedCallViewController else {
            return
        }
        guard let max = self.viewController, let callWindow = self.window else {
            return
        }
        
        self.isMinimized = minimized
        let duration: TimeInterval = 0.3
        if minimized {
            min.call = activeCall
            min.view.alpha = 0
            min.placeViewToTopRight()
            let scaleX = min.contentView.frame.width / max.view.frame.width
            let scaleY = min.contentView.frame.height / max.view.frame.height
            UIView.animate(withDuration: duration, animations: {
                min.view.alpha = 1
                max.view.transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
                max.view.center = min.view.center
                max.view.alpha = 0
                max.setNeedsStatusBarAppearanceUpdate()
            }) { (_) in
                AppDelegate.current.mainWindow.makeKeyAndVisible()
            }
        } else {
            callWindow.makeKeyAndVisible()
            UIView.animate(withDuration: duration, animations: {
                min.view.alpha = 0
                max.view.transform = .identity
                max.view.center = CGPoint(x: callWindow.bounds.midX, y: callWindow.bounds.midY)
                max.view.alpha = 1
                max.setNeedsStatusBarAppearanceUpdate()
            }) { (_) in
                min.call = nil
            }
        }
    }
    
    func handlePendingWebRTCJobs() {
        queue.async {
            let jobs = JobDAO.shared.nextBatchJobs(category: .Task, action: .PENDING_WEBRTC, limit: nil)
            for job in jobs {
                let data = job.toBlazeMessageData()
                let isOffer = data.category == MessageCategory.WEBRTC_AUDIO_OFFER.rawValue
                let isTimedOut = abs(data.createdAt.toUTCDate().timeIntervalSinceNow) >= callTimeoutInterval
                if isOffer && isTimedOut {
                    let msg = Message.createWebRTCMessage(messageId: data.messageId,
                                                          conversationId: data.conversationId,
                                                          userId: data.userId,
                                                          category: .WEBRTC_AUDIO_CANCEL,
                                                          mediaDuration: 0,
                                                          status: .DELIVERED)
                    MessageDAO.shared.insertMessage(message: msg, messageSource: "")
                } else if !isOffer || !MessageDAO.shared.isExist(messageId: data.messageId) {
                    self.handleIncomingBlazeMessageData(data)
                }
                JobDAO.shared.removeJob(jobId: job.jobId)
            }
        }
    }
    
    func requestInCallUserIds(forConversationWith id: String, completion: @escaping ([String]) -> Void) {
        queue.async {
            let ids = self.inGroupCallUserIds[id] ?? []
            DispatchQueue.main.async {
                completion(ids)
            }
        }
    }
    
    func beginPollingKrakenList(forConversationWith id: String) {
        endPollingKrakenList(forConversationWith: id)
        let timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true, block: { [weak self] (_) in
            guard let peers = SendMessageService.shared.requestKrakenPeers(forConversationWith: id) else {
                return
            }
            guard let self = self else {
                return
            }
            self.queue.async {
                self.inGroupCallUserIds[id] = peers.map(\.userId)
            }
        })
        krakenListPollingTimers.setObject(timer, forKey: id as NSString)
    }
    
    func endPollingKrakenList(forConversationWith id: String) {
        guard let timer = krakenListPollingTimers.object(forKey: id as NSString) else {
            return
        }
        timer.invalidate()
    }
    
    func alert(error: CallError) {
        let content = error.alertContent
        DispatchQueue.main.async {
            guard let controller = UIApplication.shared.keyWindow?.rootViewController else {
                return
            }
            if case .microphonePermissionDenied = error {
                controller.alertSettings(content)
            } else {
                controller.alert(content)
            }
        }
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
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        guard LoginManager.shared.isLoggedIn, !AppGroupUserDefaults.User.needsUpgradeInMainApp else {
            nativeCallInterface.reportImmediateFailureCall()
            completion()
            return
        }
        guard let messageId = payload.dictionaryPayload["message_id"] as? String, let uuid = UUID(uuidString: messageId) else {
            nativeCallInterface.reportImmediateFailureCall()
            completion()
            return
        }
        guard let userId = payload.dictionaryPayload["user_id"] as? String, let username = payload.dictionaryPayload["full_name"] as? String else {
            nativeCallInterface.reportImmediateFailureCall()
            completion()
            return
        }
        DispatchQueue.main.async {
            self.beginAutoCancellingBackgroundTaskIfNotActive()
            MixinService.isStopProcessMessages = false
            WebSocketService.shared.connectIfNeeded()
        }
        if usesCallKit && !MessageDAO.shared.isExist(messageId: messageId) {
            let call = PeerToPeerCall(uuid: uuid, isOutgoing: false, remoteUserId: userId, remoteUsername: username)
            pendingAnswerCalls[uuid] = call
            nativeCallInterface.reportIncomingCall(uuid: uuid, handleId: userId, localizedName: username) { (error) in
                completion()
            }
        } else {
            nativeCallInterface.reportImmediateFailureCall()
            completion()
        }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP, registry.pushToken(for: .voIP) == nil else {
            return
        }
        AccountAPI.shared.updateSession(voipToken: voipTokenRemove)
    }
    
}

// MARK: - Interface
extension CallService {
    
    func requestStartCall(remoteUser: UserItem) {
        let handle = CXHandle(type: .generic, value: remoteUser.userId)
        requestStartCall(handle: handle, playOutgoingRingtone: true, makeCall: { uuid in
            PeerToPeerCall(uuid: uuid, isOutgoing: true, remoteUser: remoteUser)
        })
    }
    
    func requestEndCall() {
        dispatch {
            guard let uuid = self.activeCall?.uuid ?? self.pendingAnswerCalls.first?.key else {
                return
            }
            self.callInterface.requestEndCall(uuid: uuid) { (error) in
                if let error = error {
                    // Don't think we would get error here
                    reporter.report(error: error)
                    self.endCall(uuid: uuid)
                }
            }
        }
    }
    
    func requestAnswerCall() {
        dispatch {
            guard let uuid = self.pendingAnswerCalls.first?.key else {
                return
            }
            self.callInterface.requestAnswerCall(uuid: uuid)
        }
    }
    
    func requestSetMute(_ muted: Bool) {
        dispatch {
            guard let uuid = self.activeCall?.uuid else {
                return
            }
            self.callInterface.requestSetMute(uuid: uuid, muted: muted) { (error) in
                if let error = error {
                    reporter.report(error: error)
                }
            }
        }
    }
    
    func requestStartGroupCall(conversation: ConversationItem, invitingUsers: [UserItem]) {
        let handle = CXHandle(type: .generic, value: conversation.conversationId)
        requestStartCall(handle: handle, playOutgoingRingtone: false, makeCall: { uuid in
            let connectedMembers = self.inGroupCallUserIds[conversation.conversationId]?.compactMap(UserDAO.shared.getUser(userId:)) ?? []
            var connectingMembers = [UserItem]()
            if let account = LoginManager.shared.account {
                let user = UserItem.createUser(from: account)
                connectingMembers.append(user)
            }
            let call = GroupCall(uuid: uuid,
                                 isOutgoing: true,
                                 conversation: conversation,
                                 connectedMembers: connectedMembers,
                                 connectingMembers: connectingMembers,
                                 invitingMembers: invitingUsers)
            return call
        })
    }
    
    func requestJoin(groupCall: GroupCall, conversation: ConversationItem) {
        let handle = CXHandle(type: .generic, value: conversation.conversationId)
        requestStartCall(handle: handle, playOutgoingRingtone: false, makeCall: { _ in
            groupCall
        })
    }
    
}

// MARK: - Callback
extension CallService {
    
    func startCall(uuid: UUID, handle: CXHandle, completion: ((Bool) -> Void)?) {
        AudioManager.shared.pause()
        dispatch {
            guard WebSocketService.shared.isConnected else {
                self.alert(error: .networkFailure)
                completion?(false)
                return
            }
            if let call = self.activeCall as? PeerToPeerCall, call.remoteUserId == handle.value {
                self.startPeerToPeerCall(call, completion: completion)
            } else if let call = self.activeCall as? GroupCall, call.uuid == uuid {
                self.startGroupCall(call, completion: completion)
            } else {
                self.alert(error: .inconsistentCallStarted)
                completion?(false)
            }
        }
    }
    
    func answerCall(uuid: UUID, completion: ((Bool) -> Void)?) {
        dispatch {
            if let call = self.pendingAnswerCalls[uuid] as? PeerToPeerCall, let sdp = self.pendingSDPs[uuid] {
                self.pendingAnswerCalls.removeValue(forKey: uuid)
                self.pendingSDPs.removeValue(forKey: uuid)
                self.answer(peerToPeerCall: call, sdp: sdp, completion: completion)
            } else if let call = self.pendingAnswerCalls[uuid] as? GroupCall {
                self.pendingAnswerCalls.removeValue(forKey: uuid)
                if let conversation = ConversationDAO.shared.getConversation(conversationId: call.conversationId) {
                    self.ringtonePlayer.stop()
                    call.status = .connecting
                    DispatchQueue.main.sync {
                        self.showCallingInterface(call: call)
                    }
                    self.requestJoin(groupCall: call, conversation: conversation)
                }
            }
        }
    }
    
    func endCall(uuid: UUID) {
        dispatch {
            DispatchQueue.main.sync(execute: self.beginAutoCancellingBackgroundTaskIfNotActive)
            if let call = (self.pendingAnswerCalls[uuid] ?? self.activeCall), call.uuid == uuid {
                let callStatusWasIncoming = call.status == .incoming
                call.status = .disconnecting
                if let call = call as? PeerToPeerCall {
                    let category: MessageCategory
                    if call.connectedDate != nil {
                        category = .WEBRTC_AUDIO_END
                    } else if call.isOutgoing {
                        category = .WEBRTC_AUDIO_CANCEL
                    } else {
                        category = .WEBRTC_AUDIO_DECLINE
                    }
                    let msg = Message.createWebRTCMessage(conversationId: call.conversationId,
                                                          category: category,
                                                          status: .SENDING,
                                                          quoteMessageId: call.uuidString)
                    SendMessageService.shared.sendWebRTCMessage(message: msg,
                                                                recipientId: call.remoteUserId)
                    self.insertCallCompletedMessage(call: call,
                                                    isUserInitiated: true,
                                                    category: category)
                } else if let call = call as? GroupCall {
                    if callStatusWasIncoming, let inviterUserId = call.inviterUserId {
                        let declining = KrakenRequest(conversationId: call.conversationId,
                                                      trackId: nil,
                                                      action: .decline(recipientId: inviterUserId))
                        SendMessageService.shared.send(krakenRequest: declining)
                    } else {
                        let end = KrakenRequest(conversationId: call.conversationId,
                                                trackId: nil,
                                                action: .end)
                        SendMessageService.shared.send(krakenRequest: end)
                    }
                }
            }
            self.close(uuid: uuid)
        }
    }
    
    func closeAll() {
        activeCall = nil
        rtcClient.close()
        unansweredTimer?.invalidate()
        pendingAnswerCalls = [:]
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
        if let call = activeCall, call.uuid == uuid {
            activeCall = nil
            rtcClient.close()
            if call.isOutgoing {
                unansweredTimer?.invalidate()
            }
        }
        pendingAnswerCalls.removeValue(forKey: uuid)
        pendingSDPs.removeValue(forKey: uuid)
        pendingCandidates.removeValue(forKey: uuid)
        if pendingAnswerCalls.isEmpty && activeCall == nil {
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
            activeCall?.uuid == uuid || pendingAnswerCalls[uuid] != nil
        }
        
        func handle(data: BlazeMessageData) {
            switch MessageCategory(rawValue: data.category) {
            case .WEBRTC_AUDIO_OFFER:
                self.handleOffer(data: data)
            case .WEBRTC_ICE_CANDIDATE:
                self.handleIceCandidate(data: data)
            case .KRAKEN_PUBLISH:
                self.handlePublishing(data: data)
            case .KRAKEN_INVITE:
                self.handleInvitation(data: data)
            case .KRAKEN_END:
                self.handleKrakenEnd(data: data)
            case .KRAKEN_DECLINE:
                self.handleKrakenDecline(data: data)
            case .KRAKEN_CANCEL:
                self.handleKrakenCancel(data: data)
            default:
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
                    } else {
                        let workItem = DispatchWorkItem(block: {
                            handle(data: data)
                            self.listPendingCallWorkItems.removeValue(forKey: uuid)
                        })
                        self.listPendingCallWorkItems[uuid] = workItem
                        self.queue.asyncAfter(deadline: .now() + self.listPendingCallDelay, execute: workItem)
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
                } else {
                    handle(data: data)
                }
            }
        }
        
    }
    
}

// MARK: - BlazeMessageData handlers
extension CallService {
    
    private func handleOffer(data: BlazeMessageData) {
        guard !MessageDAO.shared.isExist(messageId: data.messageId) else {
            return
        }
        
        func handle(error: Error, username: String?) {
            
            func declineOffer(data: BlazeMessageData, category: MessageCategory) {
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
                return
            }
            guard let uuid = UUID(uuidString: data.messageId) else {
                handle(error: CallError.invalidUUID(uuid: data.messageId), username: user.fullName)
                return
            }
            DispatchQueue.main.async {
                self.handledUUIDs.insert(uuid)
            }
            guard let sdpString = data.data.base64Decoded(), let sdp = RTCSessionDescription(jsonString: sdpString) else {
                handle(error: CallError.invalidSdp(sdp: data.data), username: user.fullName)
                return
            }
            AudioManager.shared.pause()
            let call = PeerToPeerCall(uuid: uuid, isOutgoing: false, remoteUser: user)
            pendingAnswerCalls[uuid] = call
            pendingSDPs[uuid] = sdp
            
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
            newCandidates.forEach(rtcClient.add(remoteCandidate:))
        } else if let uuid = UUID(uuidString: data.quoteMessageId) {
            var candidates = pendingCandidates[uuid] ?? []
            candidates.append(contentsOf: newCandidates)
            pendingCandidates[uuid] = candidates
        }
    }
    
    private func handleCallStatusChange(data: BlazeMessageData) {
        guard let uuid = UUID(uuidString: data.quoteMessageId) else {
            return
        }
        if let call = activeCall as? PeerToPeerCall, uuid == call.uuid, call.isOutgoing, data.category == MessageCategory.WEBRTC_AUDIO_ANSWER.rawValue, let sdpString = data.data.base64Decoded(), let sdp = RTCSessionDescription(jsonString: sdpString) {
            callInterface.reportOutgoingCallStartedConnecting(uuid: uuid)
            call.hasReceivedRemoteAnswer = true
            unansweredTimer?.invalidate()
            ringtonePlayer.stop()
            call.status = .connecting
            rtcClient.set(remoteSdp: sdp) { (error) in
                if let error = error {
                    self.failCurrentCall(sendFailedMessageToRemote: true,
                                         error: .setRemoteAnswer(error))
                    self.callInterface.reportCall(uuid: uuid,
                                                  endedByReason: .failed)
                }
            }
        } else if let category = MessageCategory(rawValue: data.category), MessageCategory.endCallCategories.contains(category) {
            if let call = (activeCall ?? pendingAnswerCalls[uuid]) as? PeerToPeerCall, call.uuid == uuid {
                call.status = .disconnecting
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
            }
            callInterface.reportCall(uuid: uuid, endedByReason: .remoteEnded)
            close(uuid: uuid)
        }
    }
    
    private func insertCallCompletedMessage(call: PeerToPeerCall, isUserInitiated: Bool, category: MessageCategory) {
        let timeIntervalSinceNow = call.connectedDate?.timeIntervalSinceNow ?? 0
        let duration = abs(timeIntervalSinceNow * millisecondsPerSecond)
        let shouldMarkMessageRead = call.isOutgoing
            || category == .WEBRTC_AUDIO_END
            || (category == .WEBRTC_AUDIO_DECLINE && isUserInitiated)
        let status: MessageStatus = shouldMarkMessageRead ? .READ : .DELIVERED
        let userId = call.isOutgoing ? myUserId : call.remoteUserId
        let msg = Message.createWebRTCMessage(messageId: call.uuidString,
                                              conversationId: call.conversationId,
                                              userId: userId,
                                              category: category,
                                              mediaDuration: Int64(duration),
                                              status: status)
        MessageDAO.shared.insertMessage(message: msg, messageSource: "")
    }
    
}

extension CallService {
    
    private func handlePublishing(data: BlazeMessageData) {
        let publishingUserId = data.userId
        updateInGroupCallUserIds(forConversationWith: data.conversationId)
        if let call = activeCall as? GroupCall, call.conversationId == data.conversationId {
            call.reportMemberWithIdStartedConnecting(data.userId)
            if let trackId = call.trackId {
                let subscribing = KrakenRequest(conversationId: call.conversationId,
                                                trackId: trackId,
                                                action: .subscribe)
                if let responseDataString = SendMessageService.shared.send(krakenRequest: subscribing)?.data, let responseData = Data(base64Encoded: responseDataString), let data = try? JSONDecoder.default.decode(KrakenPublishResponse.self, from: responseData), let sdpJson = data.jsep.base64Decoded(), let sdp = RTCSessionDescription(jsonString: sdpJson) {
                    rtcClient.set(remoteSdp: sdp) { (error) in
                        func endCall(error: Error) {
                            self.callInterface.reportCall(uuid: call.uuid, endedByReason: .failed)
                            self.alert(error: .setRemoteAnswer(error))
                            let end = KrakenRequest(conversationId: call.conversationId,
                                                    trackId: data.trackId,
                                                    action: .end)
                            SendMessageService.shared.send(krakenRequest: end)
                            self.close(uuid: call.uuid)
                        }
                        if let error = error {
                            endCall(error: error)
                        } else {
                            self.rtcClient.answer { (result) in
                                switch result {
                                case .success(let sdpJson):
                                    let answer = KrakenRequest(conversationId: call.conversationId,
                                                               trackId: trackId,
                                                               action: .answer(sdp: sdpJson))
                                    SendMessageService.shared.send(krakenRequest: answer)
                                    call.reportMemberWithIdDidConnected(publishingUserId)
                                case .failure(let error):
                                    endCall(error: error)
                                }
                            }
                        }
                    }
                }
            }
        } else {
            NotificationCenter.default.postOnMain(name: Self.didReceivePublishingWithoutActiveGroupCall,
                                                  object: self,
                                                  userInfo: [Self.conversationIdUserInfoKey: data.conversationId])
        }
    }
    
    private func handleInvitation(data: BlazeMessageData) {
        do {
            DispatchQueue.main.sync(execute: beginAutoCancellingBackgroundTaskIfNotActive)
            AudioManager.shared.pause()
            guard let uuid = UUID(uuidString: data.conversationId) else {
                return
            }
            guard let conversation = ConversationDAO.shared.getConversation(conversationId: data.conversationId) else {
                return
            }
            updateInGroupCallUserIds(forConversationWith: data.conversationId)
            let connectedMembers: [UserItem] = {
                if let userIds = inGroupCallUserIds[data.conversationId] {
                    return userIds.compactMap(UserDAO.shared.getUser(userId:))
                } else {
                    return []
                }
            }()
            let connectingMembers: [UserItem] = {
                if let account = LoginManager.shared.account {
                    let user = UserItem.createUser(from: account)
                    return [user]
                } else {
                    return []
                }
            }()
            let call = GroupCall(uuid: uuid,
                                 isOutgoing: false,
                                 conversation: conversation,
                                 connectedMembers: connectedMembers,
                                 connectingMembers: connectingMembers,
                                 invitingMembers: [])
            call.inviterUserId = data.userId
            pendingAnswerCalls[uuid] = call
            callInterface.reportIncomingCall(call) { (error) in
                guard let error = error else {
                    return
                }
                let publishing = Message.createKrakenStatusMessage(category: .KRAKEN_PUBLISH,
                                                                   conversationId: data.conversationId,
                                                                   userId: data.userId)
                MessageDAO.shared.insertMessage(message: publishing, messageSource: "")
                let declining = KrakenRequest(conversationId: data.conversationId,
                                              trackId: nil,
                                              action: .decline(recipientId: data.userId))
                SendMessageService.shared.send(krakenRequest: declining)
                self.close(uuid: uuid)
                reporter.report(error: error)
            }
        }
    }
    
    private func handleKrakenEnd(data: BlazeMessageData) {
        inGroupCallUserIds[data.conversationId]?.removeAll(where: { $0 == data.userId })
        if let call = activeCall as? GroupCall {
            call.reportMemberWithIdDidDisconnected(data.userId)
        }
    }
    
    private func handleKrakenDecline(data: BlazeMessageData) {
        guard let call = activeCall as? GroupCall else {
            return
        }
        call.reportMemberWithIdDidDisconnected(data.userId)
    }
    
    private func handleKrakenCancel(data: BlazeMessageData) {
        guard let uuid = UUID(uuidString: data.conversationId) else {
            return
        }
        guard let call = activeCall ?? pendingAnswerCalls.removeValue(forKey: uuid) else {
            return
        }
        guard call.uuid == uuid, call.status == .incoming else {
            return
        }
        call.status = .disconnecting
        callInterface.reportCall(uuid: uuid, endedByReason: .remoteEnded)
        close(uuid: uuid)
    }
    
}

// MARK: - WebRTCClientDelegate
extension CallService: WebRTCClientDelegate {
    
    func webRTCClient(_ client: WebRTCClient, didGenerateLocalCandidate candidate: RTCIceCandidate) {
        queue.async {
            if let call = self.activeCall as? PeerToPeerCall, let content = [candidate].jsonString {
                let msg = Message.createWebRTCMessage(conversationId: call.conversationId,
                                                      category: .WEBRTC_ICE_CANDIDATE,
                                                      content: content,
                                                      status: .SENDING,
                                                      quoteMessageId: call.uuidString)
                SendMessageService.shared.sendMessage(message: msg,
                                                      ownerUser: call.remoteUser,
                                                      isGroupMessage: false)
            } else if let call = self.activeCall as? GroupCall, let json = candidate.jsonString?.base64Encoded() {
                if let trackId = call.trackId {
                    let request = KrakenRequest(conversationId: call.conversationId,
                                                trackId: trackId,
                                                action: .trickle(candidate: json))
                    SendMessageService.shared.send(krakenRequest: request)
                } else {
                    var trickles = self.pendingTrickles[call.uuid] ?? []
                    trickles.append(json)
                    self.pendingTrickles[call.uuid] = trickles
                }
            }
        }
    }
    
    func webRTCClientDidConnected(_ client: WebRTCClient) {
        queue.async {
            guard let call = self.activeCall, call.connectedDate == nil else {
                return
            }
            let date = Date()
            call.connectedDate = date
            if call.isOutgoing {
                self.callInterface.reportOutgoingCall(uuid: call.uuid, connectedAtDate: date)
            } else {
                self.callInterface.reportIncomingCall(uuid: call.uuid, connectedAtDate: date)
            }
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            call.status = .connected
        }
        updateAudioSessionConfiguration()
    }
    
    func webRTCClientDidFailed(_ client: WebRTCClient) {
        dispatch {
            self.failCurrentCall(sendFailedMessageToRemote: true, error: .clientFailure)
        }
    }
    
}

// MARK: - Private works
extension CallService {
    
    @objc private func unansweredTimeout() {
        if let call = activeCall as? PeerToPeerCall, call.isOutgoing, !call.hasReceivedRemoteAnswer {
            dismissCallingInterface()
            rtcClient.close()
            isMuted = false
            dispatch {
                self.ringtonePlayer.stop()
                let msg = Message.createWebRTCMessage(conversationId: call.conversationId,
                                                      category: .WEBRTC_AUDIO_CANCEL,
                                                      status: .SENDING,
                                                      quoteMessageId: call.uuidString)
                SendMessageService.shared.sendWebRTCMessage(message: msg, recipientId: call.remoteUserId)
                self.insertCallCompletedMessage(call: call, isUserInitiated: false, category: .WEBRTC_AUDIO_CANCEL)
                self.activeCall = nil
                self.callInterface.reportCall(uuid: call.uuid, endedByReason: .unanswered)
            }
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
        usesCallKit = false
    }
    
    private func failCurrentCall(sendFailedMessageToRemote: Bool, error: CallError) {
        if let call = activeCall as? PeerToPeerCall {
            if sendFailedMessageToRemote {
                let msg = Message.createWebRTCMessage(conversationId: call.conversationId,
                                                      category: .WEBRTC_AUDIO_FAILED,
                                                      status: .SENDING,
                                                      quoteMessageId: call.uuidString)
                SendMessageService.shared.sendMessage(message: msg,
                                                      ownerUser: call.remoteUser,
                                                      isGroupMessage: false)
            }
            let failedMessage = Message.createWebRTCMessage(messageId: call.uuidString,
                                                            conversationId: call.conversationId,
                                                            category: .WEBRTC_AUDIO_FAILED,
                                                            status: .DELIVERED)
            MessageDAO.shared.insertMessage(message: failedMessage, messageSource: "")
            close(uuid: call.uuid)
        } else if let call = activeCall as? GroupCall {
            if sendFailedMessageToRemote {
                let request = KrakenRequest(conversationId: call.conversationId,
                                            trackId: call.trackId,
                                            action: .end)
                SendMessageService.shared.send(krakenRequest: request)
            }
            let msg = Message.createKrakenStatusMessage(category: .KRAKEN_END,
                                                        conversationId: call.conversationId,
                                                        userId: "")
            MessageDAO.shared.insertMessage(message: msg, messageSource: "")
            close(uuid: call.uuid)
        }
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
    
    private func requestStartCall(handle: CXHandle, playOutgoingRingtone: Bool, makeCall: @escaping (UUID) -> Call) {
        
        func performRequest() {
            guard activeCall == nil else {
                alert(error: .busy)
                return
            }
            updateCallKitAvailability()
            registerForPushKitNotificationsIfAvailable()
            let uuid = UUID()
            let call = makeCall(uuid)
            activeCall = call
            callInterface.requestStartCall(uuid: call.uuid, handle: handle, playOutgoingRingtone: playOutgoingRingtone) { (error) in
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
                    self.alert(error: .microphonePermissionDenied)
                }
            }
        }
        
    }
    
    private func answer(peerToPeerCall call: PeerToPeerCall, sdp: RTCSessionDescription, completion: ((Bool) -> Void)?) {
        self.activeCall = call
        call.status = .connecting
        DispatchQueue.main.sync {
            self.showCallingInterface(call: call)
        }
        
        for uuid in self.pendingAnswerCalls.keys {
            self.endCall(uuid: uuid)
        }
        self.ringtonePlayer.stop()
        self.rtcClient.set(remoteSdp: sdp) { (error) in
            if let error = error {
                self.failCurrentCall(sendFailedMessageToRemote: true,
                                     error: .setRemoteSdp(error))
                completion?(false)
            } else {
                self.rtcClient.answer(completion: { result in
                    switch result {
                    case .success(let sdpJson):
                        let msg = Message.createWebRTCMessage(conversationId: call.conversationId,
                                                              category: .WEBRTC_AUDIO_ANSWER,
                                                              content: sdpJson,
                                                              status: .SENDING,
                                                              quoteMessageId: call.uuidString)
                        SendMessageService.shared.sendMessage(message: msg,
                                                              ownerUser: call.remoteUser,
                                                              isGroupMessage: false)
                        if let candidates = self.pendingCandidates.removeValue(forKey: call.uuid) {
                            candidates.forEach(self.rtcClient.add(remoteCandidate:))
                        }
                        completion?(true)
                    case .failure(let error):
                        self.failCurrentCall(sendFailedMessageToRemote: true,
                                             error: error)
                        completion?(false)
                    }
                })
            }
        }
    }
    
    private func startPeerToPeerCall(_ call: PeerToPeerCall, completion: ((Bool) -> Void)?) {
        guard let remoteUser = call.remoteUser ?? UserDAO.shared.getUser(userId: call.remoteUserId) else {
            self.alert(error: .missingUser(userId: call.remoteUserId))
            completion?(false)
            return
        }
        call.remoteUser = remoteUser
        call.status = .outgoing
        DispatchQueue.main.sync {
            self.showCallingInterface(call: call)
        }
        
        let timer = Timer(timeInterval: callTimeoutInterval,
                          target: self,
                          selector: #selector(self.unansweredTimeout),
                          userInfo: nil,
                          repeats: false)
        RunLoop.main.add(timer, forMode: .default)
        self.unansweredTimer = timer
        
        self.rtcClient.offer { result in
            switch result {
            case .success(let sdpJson):
                let msg = Message.createWebRTCMessage(messageId: call.uuidString,
                                                      conversationId: call.conversationId,
                                                      category: .WEBRTC_AUDIO_OFFER,
                                                      content: sdpJson,
                                                      status: .SENDING)
                SendMessageService.shared.sendMessage(message: msg,
                                                      ownerUser: remoteUser,
                                                      isGroupMessage: false)
                completion?(true)
            case .failure(let error):
                self.failCurrentCall(sendFailedMessageToRemote: false, error: error)
                completion?(false)
            }
        }
    }
    
    private func startGroupCall(_ call: GroupCall, completion: ((Bool) -> Void)?) {
        call.status = call.isOutgoing ? .outgoing : .incoming
        DispatchQueue.main.sync {
            self.showCallingInterface(call: call)
        }
        rtcClient.offer { result in
            switch result {
            case .failure(let error):
                self.failCurrentCall(sendFailedMessageToRemote: false, error: error)
                completion?(false)
            case .success(let sdp):
                let request = KrakenRequest(conversationId: call.conversationId,
                                            trackId: nil,
                                            action: .publish(sdp: sdp))
                guard let responseDataString = SendMessageService.shared.send(krakenRequest: request)?.data, let responseData = Data(base64Encoded: responseDataString), let data = try? JSONDecoder.default.decode(KrakenPublishResponse.self, from: responseData), let sdpJson = data.jsep.base64Decoded(), let sdp = RTCSessionDescription(jsonString: sdpJson) else {
                    self.alert(error: .invalidKrakenResponse)
                    completion?(false)
                    return
                }
                self.callInterface.reportOutgoingCallStartedConnecting(uuid: call.uuid)
                call.trackId = data.trackId
                let msg = Message.createKrakenStatusMessage(category: .KRAKEN_PUBLISH,
                                                            conversationId: call.conversationId,
                                                            userId: myUserId)
                MessageDAO.shared.insertMessage(message: msg, messageSource: "")
                self.rtcClient.set(remoteSdp: sdp) { (error) in
                    if let error = error {
                        self.callInterface.reportCall(uuid: call.uuid, endedByReason: .failed)
                        self.alert(error: .setRemoteAnswer(error))
                        let end = KrakenRequest(conversationId: call.conversationId,
                                                trackId: data.trackId,
                                                action: .end)
                        SendMessageService.shared.send(krakenRequest: end)
                        completion?(false)
                        self.close(uuid: call.uuid)
                    } else {
                        let subscribing = KrakenRequest(conversationId: call.conversationId,
                                                        trackId: data.trackId,
                                                        action: .subscribe)
                        SendMessageService.shared.send(krakenRequest: subscribing)
                        self.pendingTrickles.removeValue(forKey: call.uuid)?.forEach({ (candidate) in
                            let trickle = KrakenRequest(conversationId: call.conversationId,
                                                        trackId: data.trackId,
                                                        action: .trickle(candidate: candidate))
                            SendMessageService.shared.send(krakenRequest: trickle)
                        })
                        call.reportMemberWithIdDidConnected(myUserId)
                        call.invitePendingUsers()
                    }
                }
                completion?(true)
            }
        }
    }
    
    private func updateInGroupCallUserIds(forConversationWith id: String) {
        guard let peers = SendMessageService.shared.requestKrakenPeers(forConversationWith: id) else {
            return
        }
        inGroupCallUserIds[id] = peers.map(\.userId)
    }
    
}
