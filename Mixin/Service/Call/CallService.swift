import Foundation
import PushKit
import CallKit
import WebRTC
import MixinServices

class CallService: NSObject {
    
    static let shared = CallService()
    static let maxNumberOfKrakenRetries: UInt = 30
    static let mutenessDidChangeNotification = Notification.Name("one.mixin.messenger.CallService.MutenessDidChange")
    static let willActivateCallNotification = Notification.Name("one.mixin.messenger.CallService.WillActivateCall")
    static let willDeactivateCallNotification = Notification.Name("one.mixin.messenger.CallService.WillDeactivateCall")
    static let callUserInfoKey = "call"
    
    let queue = DispatchQueue(label: "one.mixin.messenger.CallService")
    
    var isMuted = false {
        didSet {
            NotificationCenter.default.postOnMain(name: Self.mutenessDidChangeNotification)
            updateAudioTrackEnabling()
        }
    }
    
    var usesSpeaker = false {
        didSet {
            updateAudioSessionConfiguration()
            self.log("[CallService] usesSpeaker: \(usesSpeaker)")
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
        return CallDurationFormatter.string(from: duration)
    }
    
    private(set) lazy var ringtonePlayer = RingtonePlayer()
    private(set) lazy var membersManager = GroupCallMembersManager(workingQueue: queue)
    
    private(set) var handledUUIDs = Set<UUID>() // Access from main queue
    private(set) var isMinimized = false
    
    // Access from CallService.queue
    private(set) var activeCall: Call? {
        willSet {
            if let call = activeCall, newValue == nil {
                NotificationCenter.default.post(name: Self.willDeactivateCallNotification, object: self, userInfo: [Self.callUserInfoKey: call])
            } else if activeCall == nil, let call = newValue {
                NotificationCenter.default.post(name: Self.willActivateCallNotification, object: self, userInfo: [Self.callUserInfoKey: call])
            }
        }
    }
    
    private let queueSpecificKey = DispatchSpecificKey<Void>()
    private let listPendingCallDelay = DispatchTimeInterval.seconds(2)
    private let retryInterval = DispatchTimeInterval.seconds(3)
    private let isMainlandChina = false
    
    private lazy var rtcClient = WebRTCClient(delegateQueue: queue)
    private lazy var nativeCallInterface = NativeCallInterface(service: self)
    private lazy var listPendingInvitationCounter = Counter(value: 0)
    
    private var pushRegistry: PKPushRegistry?
    
    private var pendingAnswerCalls = [UUID: Call]()
    private var pendingSDPs = [UUID: RTCSessionDescription]()
    private var pendingCandidates = [UUID: [RTCIceCandidate]]()
    private var pendingTrickles = [UUID: [String]]() // Key is Call's UUID, Value is array of candidate string
    private var listPendingCallWorkItems = [UUID: DispatchWorkItem]()
    private var listPendingInvitations = [Int: BlazeMessageData]()
    
    // CallKit identify a call with an *unique* UUID, any duplication will cause undocumented behavior
    // Since there's no unique id provided by backend, but only one call is allowed per-conversation,
    // We map conversation id with uuid here
    private var groupCallUUIDs = [String: UUID]()
    
    private var window: CallWindow?
    private var viewController: CallViewController?
    
    // Access from CallService.queue
    private var callInterface: CallInterface!
    
    private var isUsingCallKit: Bool {
        callInterface.isEqual(nativeCallInterface)
    }
    
    override init() {
        super.init()
        queue.setSpecific(key: queueSpecificKey, value: ())
        rtcClient.delegate = self
        updateCallKitAvailability()
        KrakenMessageRetriever.shared.delegate = self
        RTCAudioSession.sharedInstance().add(self)
    }
    
    func registerForPushKitNotificationsIfAvailable() {
        dispatch {
            guard self.pushRegistry == nil else {
                return
            }
            guard self.isUsingCallKit else {
                AccountAPI.updateSession(voipToken: voipTokenRemove)
                return
            }
            let registry = PKPushRegistry(queue: self.queue)
            registry.desiredPushTypes = [.voIP]
            registry.delegate = self
            if let token = registry.pushToken(for: .voIP)?.toHexString() {
                AccountAPI.updateSession(voipToken: token)
            }
            self.pushRegistry = registry
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
    
    func hasPendingSDP(for uuid: UUID) -> Bool {
        pendingSDPs[uuid] != nil
    }
    
    func hasPendingAnswerGroupCall(with uuid: UUID) -> Bool {
        if let call = activeCall, call.uuid == uuid {
            return true
        } else if let call = pendingAnswerCalls[uuid], call is GroupCall {
            return true
        } else {
            return false
        }
    }
    
    func hasCall(with uuid: UUID) -> Bool {
        activeOrPendingAnswerCall(with: uuid) != nil
    }
    
    func minimizeIfThereIsAnActiveCall() {
        queue.async {
            guard self.activeCall != nil else {
                return
            }
            DispatchQueue.main.sync {
                guard !self.isMinimized else {
                    return
                }
                self.setInterfaceMinimized(true, animated: true)
            }
        }
    }
    
    func alert(error: Error) {
        let content: String
        if let error = error as? CallError {
            content = error.alertContent
        } else {
            content = R.string.localizable.chat_message_call_failed()
        }
        DispatchQueue.main.async {
            guard let controller = AppDelegate.current.mainWindow.rootViewController else {
                return
            }
            switch error {
            case CallError.microphonePermissionDenied:
                controller.alertSettings(content)
            default:
                controller.alert(content)
            }
        }
    }
    
    func log(_ log: String) {
        NSLog(log)
        Logger.write(log: "[Call]" + log)
    }
    
}

// MARK: - Calling Interface
extension CallService {
    
    func requestStartPeerToPeerCall(remoteUser: UserItem) {
        self.log("[CallService] Request start p2p call with user: \(remoteUser.fullName)")
        let handle = CXHandle(type: .generic, value: remoteUser.userId)
        let call = PeerToPeerCall(uuid: UUID(), isOutgoing: true, remoteUser: remoteUser)
        requestStartCall(call, handle: handle, playOutgoingRingtone: true)
    }
    
    func requestStartGroupCall(conversation: ConversationItem, invitingMembers: [UserItem]) {
        self.log("[CallService] Request start group call with conversation: \(conversation.getConversationName())")
        guard var members = self.membersManager.members(inConversationWith: conversation.conversationId) else {
            alert(error: CallError.networkFailure)
            return
        }
        if let account = LoginManager.shared.account {
            let me = UserItem.createUser(from: account)
            members.append(me)
        }
        self.log("[CallService] Making call with members: \(members.map(\.fullName))")
        let call = GroupCall(uuid: UUID(),
                             isOutgoing: true,
                             conversation: conversation,
                             members: members,
                             invitingMembers: invitingMembers)
        let handle = CXHandle(type: .generic, value: conversation.conversationId)
        requestStartCall(call, handle: handle, playOutgoingRingtone: false)
    }
    
    func requestAnswerCall() {
        queue.async {
            guard let uuid = self.pendingAnswerCalls.first?.key else {
                self.log("[CallService] Request answer call but finds no pending answer call")
                return
            }
            self.log("[CallService] Request answer call")
            self.callInterface.requestAnswerCall(uuid: uuid)
        }
    }
    
    func requestEndCall() {
        queue.async {
            guard let uuid = self.activeCall?.uuid ?? self.pendingAnswerCalls.first?.key else {
                self.log("[CallService] Request end call but finds no pending answer call")
                return
            }
            self.log("[CallService] Request end call")
            self.callInterface.requestEndCall(uuid: uuid) { (error) in
                if let error = error {
                    self.log("[CallService] Error request end call: \(error)")
                    // Don't think we would get error here
                    reporter.report(error: error)
                    self.endCall(uuid: uuid)
                }
            }
        }
    }
    
    func requestSetMute(_ muted: Bool) {
        queue.async {
            guard let uuid = self.activeCall?.uuid ?? self.pendingAnswerCalls.first?.key else {
                self.log("[CallService] Request set mute but finds no pending answer call")
                return
            }
            self.log("[CallService] Request set mute")
            self.callInterface.requestSetMute(uuid: uuid, muted: muted) { (_) in }
        }
    }
    
}

// MARK: - UI Related Interface
extension CallService {
    
    func showJoinGroupCallConfirmation(conversation: ConversationItem, memberIds ids: [String]) {
        let controller = GroupCallConfirmationViewController(conversation: conversation, service: self)
        controller.loadMembers(with: ids)
        
        let window = self.window ?? CallWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window
        
        UIView.performWithoutAnimation(controller.view.layoutIfNeeded)
    }
    
    func showCallingInterface(call: Call) {
        self.log("[CallService] show calling interface for call: \(call.debugDescription)")
        
        if isMinimized {
            setInterfaceMinimized(false, animated: false)
        }
        
        func makeViewController() -> CallViewController {
            let viewController = CallViewController(service: self)
            viewController.loadViewIfNeeded()
            self.viewController = viewController
            return viewController
        }
        
        let viewController = self.viewController ?? makeViewController()
        let window = self.window ?? CallWindow(frame: UIScreen.main.bounds)
        let animated = window.rootViewController == viewController
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        self.window = window
        
        UIView.performWithoutAnimation(viewController.view.layoutIfNeeded)
        
        let updateInterface = {
            viewController.reload(call: call)
            viewController.view.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: 0.3, animations: updateInterface)
        } else {
            UIView.performWithoutAnimation(updateInterface)
        }
    }
    
    func setInterfaceMinimized(_ minimized: Bool, animated: Bool) {
        self.isMinimized = minimized
        guard let min = UIApplication.homeContainerViewController?.minimizedCallViewController else {
            return
        }
        guard let max = self.viewController, let callWindow = self.window else {
            return
        }
        let duration: TimeInterval = 0.3
        let updateViews: () -> Void
        let completion: (Bool) -> Void
        if minimized {
            min.call = activeCall
            min.view.alpha = 0
            let scaleX = min.contentView.frame.width / max.view.frame.width
            let scaleY = min.contentView.frame.height / max.view.frame.height
            updateViews = {
                min.view.alpha = 1
                max.view.transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
                max.view.center = min.view.center
                max.view.alpha = 0
                max.setNeedsStatusBarAppearanceUpdate()
            }
            completion = { (_) in
                AppDelegate.current.mainWindow.makeKeyAndVisible()
            }
        } else {
            callWindow.makeKeyAndVisible()
            max.view.center = min.view.center
            updateViews = {
                min.view.alpha = 0
                max.view.transform = .identity
                max.view.center = CGPoint(x: callWindow.bounds.midX, y: callWindow.bounds.midY)
                max.view.alpha = 1
                max.setNeedsStatusBarAppearanceUpdate()
            }
            completion = { (_) in
                min.call = nil
            }
        }
        if animated {
            UIView.animate(withDuration: duration, animations: updateViews, completion: completion)
        } else {
            updateViews()
            completion(true)
        }
    }
    
    func dismissCallingInterface() {
        AppDelegate.current.mainWindow.makeKeyAndVisible()
        if let mini = UIApplication.homeContainerViewController?.minimizedCallViewControllerIfLoaded {
            mini.view.alpha = 0
            mini.placeViewToTopRight()
        }
        viewController?.disableConnectionDurationTimer()
        viewController = nil
        window = nil
        self.log("[CallService] calling interface dismissed")
    }
    
}

// MARK: - Callback
extension CallService {
    
    func startCall(uuid: UUID, handle: CXHandle, completion: ((Bool) -> Void)?) {
        AudioManager.shared.pause()
        dispatch {
            guard WebSocketService.shared.isConnected else {
                self.activeCall = nil
                self.alert(error: CallError.networkFailure)
                completion?(false)
                return
            }
            if let call = self.activeCall as? PeerToPeerCall, call.remoteUserId == handle.value, call.status != .disconnecting {
                self.startPeerToPeerCall(call, completion: completion)
                self.log("[CallService] start p2p call")
            } else if let call = self.activeCall as? GroupCall, call.uuid == uuid, call.status != .disconnecting {
                self.startGroupCall(call, isRestarting: false, completion: completion)
                self.log("[CallService] start group call")
            } else {
                self.alert(error: CallError.inconsistentCallStarted)
                self.log("[CallService] inconsistentCallStarted")
                completion?(false)
            }
        }
    }
    
    func answerCall(uuid: UUID, completion: ((Bool) -> Void)?) {
        dispatch {
            if let call = self.pendingAnswerCalls[uuid] as? PeerToPeerCall, call.status != .disconnecting, let sdp = self.pendingSDPs[uuid] {
                self.log("[CallService] answer p2p call: \(call.debugDescription)")
                call.timer?.invalidate()
                self.pendingAnswerCalls.removeValue(forKey: uuid)
                self.pendingSDPs.removeValue(forKey: uuid)
                self.answer(peerToPeerCall: call, sdp: sdp, completion: completion)
            } else if let call = self.pendingAnswerCalls[uuid] as? GroupCall, call.status != .disconnecting {
                DispatchQueue.main.sync {
                    _ = self.handledUUIDs.insert(uuid)
                }
                self.log("[CallService] answer group call: \(call.debugDescription)")
                call.timer?.invalidate()
                self.pendingAnswerCalls.removeValue(forKey: uuid)
                self.activeCall = call
                self.ringtonePlayer.stop()
                call.status = .connecting
                self.startGroupCall(call, isRestarting: false, completion: completion)
            } else {
                self.log("[CallService] answer call failed, call: \(self.pendingAnswerCalls[uuid]?.debugDescription)")
            }
        }
    }
    
    func endCall(uuid: UUID) {
        dispatch {
            DispatchQueue.main.sync(execute: self.beginAutoCancellingBackgroundTaskIfNotActive)
            if let call = self.activeOrPendingAnswerCall(with: uuid) {
                let callStatusWasIncoming = call.status == .incoming
                call.status = .disconnecting
                call.timer?.invalidate()
                self.log("[CallService] ending call: \(call.debugDescription)")
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
                    DispatchQueue.main.sync {
                        _ = self.handledUUIDs.insert(uuid)
                    }
                    if callStatusWasIncoming, !call.inviters.isEmpty {
                        for userId in call.inviters.map(\.userId) {
                            let declining = KrakenRequest(callUUID: call.uuid,
                                                          conversationId: call.conversationId,
                                                          trackId: nil,
                                                          action: .decline(recipientId: userId))
                            KrakenMessageRetriever.shared.request(declining, completion: nil)
                            self.log("[KrakenMessageRetriever] Request \(declining.debugDescription)")
                        }
                        let message = Message.createKrakenMessage(conversationId: call.conversationId,
                                                                  userId: myUserId,
                                                                  category: .KRAKEN_DECLINE,
                                                                  createdAt: Date().toUTCString())
                        MessageDAO.shared.insertMessage(message: message, messageSource: "CallService")
                    } else {
                        let action: KrakenRequest.Action
                        let messageCategory: MessageCategory
                        if call.isOutgoing, call.trackId == nil {
                            action = .cancel
                            messageCategory = .KRAKEN_CANCEL
                        } else {
                            action = .end
                            messageCategory = .KRAKEN_END
                        }
                        let mediaDuration: Int64?
                        if let date = call.connectedDate {
                            mediaDuration = Int64(abs(date.timeIntervalSinceNow) * millisecondsPerSecond)
                        } else {
                            mediaDuration = nil
                        }
                        let end = KrakenRequest(callUUID: uuid,
                                                conversationId: call.conversationId,
                                                trackId: call.trackId,
                                                action: action)
                        KrakenMessageRetriever.shared.request(end, completion: nil)
                        self.log("[KrakenMessageRetriever] Request \(end.debugDescription)")
                        let message = Message.createKrakenMessage(conversationId: call.conversationId,
                                                                  userId: myUserId,
                                                                  category: messageCategory,
                                                                  mediaDuration: mediaDuration,
                                                                  createdAt: Date().toUTCString())
                        MessageDAO.shared.insertMessage(message: message, messageSource: "CallService")
                    }
                    self.membersManager.removeMember(with: myUserId, fromConversationWith: call.conversationId)
                }
            }
            self.close(uuid: uuid)
        }
    }
    
    func closeAll() {
        self.log("[CallService] close all call")
        activeCall?.timer?.invalidate()
        activeCall = nil
        rtcClient.close()
        for timer in pendingAnswerCalls.values.compactMap(\.timer) {
            timer.invalidate()
        }
        pendingAnswerCalls = [:]
        pendingSDPs = [:]
        pendingCandidates = [:]
        pendingTrickles = [:]
        ringtonePlayer.stop()
        performSynchronouslyOnMainThread {
            dismissCallingInterface()
        }
        isMuted = false
        usesSpeaker = false
        if !isUsingCallKit {
            RTCDispatcher.dispatchAsync(on: .typeAudioSession) {
                RTCAudioSession.sharedInstance().isAudioEnabled = false
            }
        }
        updateCallKitAvailability()
        registerForPushKitNotificationsIfAvailable()
    }
    
    func close(uuid: UUID) {
        self.log("[CallService] close call: \(uuid)")
        if let call = activeCall, call.uuid == uuid {
            activeCall = nil
            rtcClient.close()
            call.timer?.invalidate()
        }
        if let call = pendingAnswerCalls.removeValue(forKey: uuid) {
            call.timer?.invalidate()
        }
        pendingSDPs.removeValue(forKey: uuid)
        pendingCandidates.removeValue(forKey: uuid)
        pendingTrickles.removeValue(forKey: uuid)
        if pendingAnswerCalls.isEmpty && activeCall == nil {
            ringtonePlayer.stop()
            performSynchronouslyOnMainThread {
                dismissCallingInterface()
            }
            isMuted = false
            usesSpeaker = false
            if !isUsingCallKit {
                RTCDispatcher.dispatchAsync(on: .typeAudioSession) {
                    RTCAudioSession.sharedInstance().isAudioEnabled = false
                }
            }
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
            case .KRAKEN_DECLINE:
                self.handleKrakenDecline(data: data)
            case .KRAKEN_END, .KRAKEN_CANCEL:
                self.handleKrakenEnd(data: data)
            default:
                self.handleCallStatusChange(data: data)
            }
        }
        
        dispatch {
            if data.source != BlazeMessageAction.listPendingMessages.rawValue {
                handle(data: data)
            } else {
                let isOffer = data.category == MessageCategory.WEBRTC_AUDIO_OFFER.rawValue
                let isTimedOut = abs(data.createdAt.toUTCDate().timeIntervalSinceNow) >= callTimeoutInterval
                if isOffer, let uuid = UUID(uuidString: data.messageId), !hasCall(uuid: uuid) {
                    if isTimedOut {
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
                } else if data.category == MessageCategory.KRAKEN_INVITE.rawValue {
                    if isTimedOut {
                        let message = Message.createKrakenMessage(conversationId: data.conversationId,
                                                                  userId: data.userId,
                                                                  category: .KRAKEN_INVITE,
                                                                  createdAt: data.createdAt)
                        MessageDAO.shared.insertMessage(message: message, messageSource: "CallService")
                    } else {
                        let index = self.listPendingInvitationCounter.advancedValue
                        self.listPendingInvitations[index] = data
                        self.queue.asyncAfter(deadline: .now() + self.listPendingCallDelay, execute: {
                            guard let invitation = self.listPendingInvitations[index] else {
                                return
                            }
                            handle(data: invitation)
                        })
                    }
                } else if data.category == MessageCategory.KRAKEN_END.rawValue {
                    self.listPendingInvitations = self.listPendingInvitations.filter({ (index, invitation) -> Bool in
                        if invitation.conversationId == data.conversationId {
                            let message = Message.createKrakenMessage(conversationId: invitation.conversationId,
                                                                      userId: invitation.userId,
                                                                      category: .KRAKEN_INVITE,
                                                                      createdAt: invitation.createdAt)
                            MessageDAO.shared.insertMessage(message: message, messageSource: "CallService")
                            return false
                        } else {
                            return true
                        }
                    })
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
                        self.alert(error: CallError.microphonePermissionDenied)
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
            if !data.quoteMessageId.isEmpty {
                if let call = activeCall as? PeerToPeerCall, call.uuid == UUID(uuidString: data.quoteMessageId), !call.isOutgoing {
                    self.log("[CallService] Got restart offer, setting it")
                    rtcClient.set(remoteSdp: sdp) { (error) in
                        self.handleResultFromSettingRemoteSdpWhenAnsweringPeerToPeerCall(call, error: error, completion: nil)
                    }
                }
            } else {
                AudioManager.shared.pause()
                let call = PeerToPeerCall(uuid: uuid, isOutgoing: false, remoteUser: user)
                pendingAnswerCalls[uuid] = call
                pendingSDPs[uuid] = sdp
                beginUnanswerCountDown(for: call)
                callInterface.reportIncomingCall(call) { (error) in
                    if let error = error {
                        handle(error: error, username: user.fullName)
                    }
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
        if let call = activeCall as? PeerToPeerCall, uuid == call.uuid, call.isOutgoing, call.status != .disconnecting, data.category == MessageCategory.WEBRTC_AUDIO_ANSWER.rawValue, let sdpString = data.data.base64Decoded(), let sdp = RTCSessionDescription(jsonString: sdpString) {
            callInterface.reportOutgoingCallStartedConnecting(uuid: uuid)
            call.hasReceivedRemoteAnswer = true
            call.timer?.invalidate()
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
            if let call = activeOrPendingAnswerCall(with: uuid) as? PeerToPeerCall {
                call.status = .disconnecting
                call.timer?.invalidate()
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

// MARK: - Kraken response handlers
extension CallService {
    
    private func handlePublishing(data: BlazeMessageData) {
        self.log("[CallService] Got publish from: \(data.userId), conversation: \(data.conversationId)")
        membersManager.addMember(with: data.userId, toConversationWith: data.conversationId)
        guard let uuid = groupCallUUIDs[data.conversationId] else {
            return
        }
        let groupCall: GroupCall?
        if let call = activeCall as? GroupCall, call.uuid == uuid {
            groupCall = call
            if call.trackId != nil {
                self.log("[CallService] The call is active with valid track id, subscribe the user: \(data.userId)")
                subscribe(userId: data.userId, of: call)
            } else {
                self.log("[CallService] no track id is found. do not subscribe it")
            }
        } else if let call = pendingAnswerCalls[uuid] as? GroupCall {
            groupCall = call
        } else {
            groupCall = nil
        }
        if let call = groupCall {
            self.log("[CallService] reportMemberWithIdDidConnected: \(data.userId)")
            call.reportMemberWithIdDidConnected(data.userId)
        } else {
            self.log("[CallService] no group call, drops: \(data.userId)")
        }
    }
    
    private func handleInvitation(data: BlazeMessageData) {
        do {
            DispatchQueue.main.sync(execute: beginAutoCancellingBackgroundTaskIfNotActive)
            self.log("[CallService] Got Invitation from: \(data.userId)")
            guard activeCall?.conversationId != data.conversationId else {
                return
            }
            if let uuid = groupCallUUIDs[data.conversationId], let call = pendingAnswerCalls[uuid] as? GroupCall, !call.inviters.contains(where: { $0.userId == data.userId }), let user = UserDAO.shared.getUser(userId: data.userId) {
                call.inviters.append(user)
                callInterface.reportIncomingCall(call, completion: { _ in })
                return
            }
            let uuid = UUID(uuidString: data.messageId) ?? UUID()
            let isUUIDHandled = DispatchQueue.main.sync {
                self.handledUUIDs.contains(uuid)
            }
            guard !isUUIDHandled else {
                // TODO: The only reason this UUID is already handled is that the user had pick accept/decline
                // from the CallKit's calling interface. Reporting incoming call will be confusing to user.
                // But I think this could be managed with an invitation message in the database
                return
            }
            guard let conversation = ConversationDAO.shared.getConversation(conversationId: data.conversationId) else {
                self.log("[CallService] no conversation: \(data.conversationId)")
                return
            }
            AudioManager.shared.pause()
            guard var members = membersManager.members(inConversationWith: data.conversationId) else {
                self.log("[CallService] failed to load members: \(data.conversationId)")
                return
            }
            if let account = LoginManager.shared.account {
                let me = UserItem.createUser(from: account)
                members.append(me)
            }
            let call = GroupCall(uuid: uuid,
                                 isOutgoing: false,
                                 conversation: conversation,
                                 members: members,
                                 invitingMembers: [])
            if let user = UserDAO.shared.getUser(userId: data.userId) {
                call.inviters = [user]
            }
            groupCallUUIDs[conversation.conversationId] = uuid
            self.log("[CallService] reporting incoming group call invitation: \(call.debugDescription), members: \(members.map(\.fullName))")
            pendingAnswerCalls[uuid] = call
            beginUnanswerCountDown(for: call)
            callInterface.reportIncomingCall(call) { (error) in
                guard let error = error else {
                    return
                }
                self.log("[CallService] incoming call reporting error: \(error)")
                let declining = KrakenRequest(callUUID: uuid,
                                              conversationId: data.conversationId,
                                              trackId: nil,
                                              action: .decline(recipientId: data.userId))
                KrakenMessageRetriever.shared.request(declining, completion: nil)
                self.log("[KrakenMessageRetriever] Request \(declining.debugDescription)")
                self.close(uuid: uuid)
                self.alert(error: error)
                if case CallError.microphonePermissionDenied = error {
                    DispatchQueue.main.async {
                        if UIApplication.shared.applicationState != .active {
                            NotificationManager.shared.requestDeclinedGroupCallNotification(localizedName: call.localizedName,
                                                                                            messageId: data.messageId)
                        }
                    }
                }
                reporter.report(error: error)
            }
            let message = Message.createKrakenMessage(conversationId: data.conversationId,
                                                      userId: data.userId,
                                                      category: .KRAKEN_INVITE,
                                                      createdAt: data.createdAt)
            MessageDAO.shared.insertMessage(message: message, messageSource: "CallService")
        }
    }
    
    private func handleKrakenDecline(data: BlazeMessageData) {
        self.log("[CallService] Got \(data.category), report member: \(data.userId) disconnected")
        reportMember(withUserId: data.userId,
                     didDisconnectFromConversationWithId: data.conversationId)
        if let call = activeCall, call.status == .connected, call.conversationId == data.conversationId {
            let message = Message.createKrakenMessage(conversationId: data.conversationId,
                                                      userId: data.userId,
                                                      category: .KRAKEN_DECLINE,
                                                      createdAt: data.createdAt)
            MessageDAO.shared.insertMessage(message: message, messageSource: "CallService")
        }
    }
    
    private func handleKrakenEnd(data: BlazeMessageData) {
        self.log("[CallService] Got kraken end from \(data.userId)")
        reportMember(withUserId: data.userId,
                     didDisconnectFromConversationWithId: data.conversationId)
        
        func shouldClose(call: GroupCall) -> Bool {
            call.inviters.removeAll(where: { $0.userId == data.userId })
            return call.conversationId == data.conversationId
                && call.inviters.isEmpty
                && call.status == .incoming
        }
        
        var calls = [GroupCall]()
        if let call = activeCall as? GroupCall, shouldClose(call: call) {
            calls.append(call)
        }
        for case let (uuid, call as GroupCall) in pendingAnswerCalls where shouldClose(call: call) {
            pendingAnswerCalls.removeValue(forKey: uuid)
            calls.append(call)
        }
        
        for call in calls {
            call.status = .disconnecting
            close(uuid: call.uuid)
            callInterface.reportCall(uuid: call.uuid, endedByReason: .remoteEnded)
            let message = Message.createKrakenMessage(conversationId: data.conversationId,
                                                      userId: data.userId,
                                                      category: .KRAKEN_CANCEL,
                                                      createdAt: data.createdAt)
            MessageDAO.shared.insertMessage(message: message, messageSource: "CallService")
        }
    }
    
    private func reportMember(withUserId userId: String, didDisconnectFromConversationWithId conversationId: String) {
        membersManager.removeMember(with: userId, fromConversationWith: conversationId)
        if let call = activeCall as? GroupCall {
            call.reportMemberWithIdDidDisconnected(userId)
        }
    }
    
}

// MARK: - Kraken response handlers
extension CallService: KrakenMessageRetrieverDelegate {
    
    func krakenMessageRetriever(_ retriever: KrakenMessageRetriever, shouldRetryRequest request: KrakenRequest, error: Swift.Error, numberOfRetries: UInt) -> Bool {
        guard LoginManager.shared.isLoggedIn else {
            return false
        }
        guard let call = activeOrPendingAnswerCall(with: request.callUUID) else {
            self.log("[CallService] no active or pending call, give up kraken retrying")
            return false
        }
        guard call.status != .disconnecting else {
            self.log("[CallService] finds a disconnecting call, give up kraken request")
            return false
        }
        switch error {
        case MixinAPIError.unauthorized:
            self.log("[CallService] Got 401 when requesting: \(request.debugDescription)")
            let error = CallError.invalidPeerConnection(.unauthorized)
            failCurrentCall(sendFailedMessageToRemote: false, error: error)
            callInterface.reportCall(uuid: request.callUUID, endedByReason: .failed)
            return false
        case MixinAPIError.peerNotFound, MixinAPIError.peerClosed, MixinAPIError.trackNotFound:
            self.log("[CallService] Got \(error) when requesting: \(request.debugDescription)")
            return false
        case MixinAPIError.roomFull:
            return false
        default:
            let shouldRetry = numberOfRetries < Self.maxNumberOfKrakenRetries
            self.log("[CallService] got error: \(error), numberOfRetries: \(numberOfRetries), returns shouldRetry: \(shouldRetry)")
            return shouldRetry
        }
    }
    
}

// MARK: - WebRTCClientDelegate
extension CallService: WebRTCClientDelegate {
    
    func webRTCClient(_ client: WebRTCClient, didGenerateLocalCandidate candidate: RTCIceCandidate) {
        if let call = activeCall as? PeerToPeerCall, let content = [candidate].jsonString {
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
                let trickle = KrakenRequest(callUUID: call.uuid,
                                            conversationId: call.conversationId,
                                            trackId: trackId,
                                            action: .trickle(candidate: json))
                KrakenMessageRetriever.shared.request(trickle, completion: nil)
                self.log("[KrakenMessageRetriever] Request \(trickle.debugDescription)")
            } else {
                var trickles = pendingTrickles[call.uuid] ?? []
                trickles.append(json)
                pendingTrickles[call.uuid] = trickles
            }
        }
    }
    
    func webRTCClientDidConnected(_ client: WebRTCClient) {
        guard let call = activeCall else {
            return
        }
        self.log("[CallService] RTC connected, reporting with: \(call.debugDescription)")
        if call.connectedDate == nil {
            let date = Date()
            call.connectedDate = date
            if call.isOutgoing {
                callInterface.reportOutgoingCall(uuid: call.uuid, connectedAtDate: date)
            } else {
                callInterface.reportIncomingCall(uuid: call.uuid, connectedAtDate: date)
            }
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            call.status = .connected
            if !isUsingCallKit {
                RTCDispatcher.dispatchAsync(on: .typeAudioSession) {
                    RTCAudioSession.sharedInstance().isAudioEnabled = true
                }
            }
            updateAudioSessionConfiguration()
        }
        DispatchQueue.main.async {
            UIView.performWithoutAnimation {
                self.viewController?.unstableConnectionLabel.isHidden = true
            }
        }
    }
    
    func webRTCClientDidDisconnected(_ client: WebRTCClient) {
        self.log("[CallService] RTC Disconnected")
        guard let call = activeCall, call.status == .connected else {
            return
        }
        DispatchQueue.main.async {
            UIView.performWithoutAnimation {
                self.viewController?.unstableConnectionLabel.isHidden = false
            }
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeIceConnectionStateTo newState: RTCIceConnectionState) {
        self.log("[CallService] RTC IceConnectionState change to: \(newState.rawValue)")
        guard newState == .failed else {
            return
        }
        self.log("[CallService] RTC IceConnectionState change to failed")
        if let call = activeCall as? PeerToPeerCall, call.isOutgoing {
            rtcClient.offer(key: nil, withIceRestartConstraint: true) { (result) in
                switch result {
                case .success(let sdpJson):
                    self.log("[CallService] Sending restart offer")
                    let msg = Message.createWebRTCMessage(messageId: UUID().uuidString.lowercased(),
                                                          conversationId: call.conversationId,
                                                          userId: myUserId,
                                                          category: .WEBRTC_AUDIO_OFFER,
                                                          content: sdpJson,
                                                          mediaDuration: nil,
                                                          status: .SENDING,
                                                          quoteMessageId: call.uuidString)
                    SendMessageService.shared.sendMessage(message: msg,
                                                          ownerUser: call.remoteUser,
                                                          isGroupMessage: false)
                case .failure(let error):
                    self.log("[CallService] Restart offer generation failed: \(error)")
                    self.failCurrentCall(sendFailedMessageToRemote: true, error: .networkFailure)
                    self.callInterface.reportCall(uuid: call.uuid, endedByReason: .failed)
                }
            }
        } else if let call = activeCall as? GroupCall {
            self.log("[CallService] Restart group call on ice failure, with restarting constraint")
            startGroupCall(call, isRestarting: true, completion: { success in
                if !success {
                    self.restartCurrentGroupCall()
                }
            })
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, senderPublicKeyForUserWith userId: String, sessionId: String) -> Data? {
        guard let call = self.activeCall as? GroupCall else {
            self.log("[CallService] request sender public key but there's no active call")
            return nil
        }
        let frameKey = SignalProtocol.shared.getSenderKeyPublic(groupId: call.conversationId,
                                                                userId: userId,
                                                                sessionId: sessionId)?.dropFirst()
        self.log("[CallService] request sender public key for userId: \(userId), sessionId: \(sessionId), returns: \(frameKey?.count ?? -1)")
        return frameKey
    }
    
    func webRTCClient(_ client: WebRTCClient, didAddReceiverWith userId: String) {
        guard let call = activeCall as? GroupCall else {
            return
        }
        self.log("[CallService] Add member: \(userId), to: \(call.conversationId), from receiver delegation")
        membersManager.addMember(with: userId, toConversationWith: call.conversationId)
        call.reportMemberWithIdDidConnected(userId)
    }
    
}

// MARK: - PKPushRegistryDelegate
extension CallService: PKPushRegistryDelegate {
    
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        guard LoginManager.shared.isLoggedIn else {
            return
        }
        let token = pushCredentials.token.toHexString()
        AccountAPI.updateSession(voipToken: token)
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        guard LoginManager.shared.isLoggedIn, !AppGroupUserDefaults.User.needsUpgradeInMainApp else {
            nativeCallInterface.reportImmediateFailureCall()
            completion()
            return
        }
        guard let userId = payload.dictionaryPayload["user_id"] as? String, let name = payload.dictionaryPayload["name"] as? String else {
            nativeCallInterface.reportImmediateFailureCall()
            completion()
            return
        }
        guard let messageId = payload.dictionaryPayload["message_id"] as? String, !MessageDAO.shared.isExist(messageId: messageId), let uuid = UUID(uuidString: messageId) else {
            nativeCallInterface.reportImmediateFailureCall()
            completion()
            return
        }
        DispatchQueue.main.async {
            self.beginAutoCancellingBackgroundTaskIfNotActive()
            MixinService.isStopProcessMessages = false
            WebSocketService.shared.connectIfNeeded()
        }
        if isUsingCallKit, !name.isEmpty, let conversationId = payload.dictionaryPayload["conversation_id"] as? String, let conversation = ConversationDAO.shared.getConversation(conversationId: conversationId) {
            let members: [UserItem]
            if let account = LoginManager.shared.account {
                let me = UserItem.createUser(from: account)
                members = [me]
            } else {
                members = []
            }
            let call = GroupCall(uuid: uuid,
                                 isOutgoing: false,
                                 conversation: conversation,
                                 members: members,
                                 invitingMembers: [])
            if let user = UserDAO.shared.getUser(userId: userId) {
                call.inviters = [user]
            }
            groupCallUUIDs[conversationId] = uuid
            pendingAnswerCalls[uuid] = call
            beginUnanswerCountDown(for: call)
            nativeCallInterface.reportIncomingCall(uuid: uuid, handleId: conversationId, localizedName: name) { (error) in
                completion()
            }
            self.log("[CallService] report incoming group call from PushKit notification: \(call.debugDescription)")
        } else if isUsingCallKit, name.isEmpty, let username = payload.dictionaryPayload["full_name"] as? String {
            let call = PeerToPeerCall(uuid: uuid, isOutgoing: false, remoteUserId: userId, remoteUsername: username)
            pendingAnswerCalls[uuid] = call
            beginUnanswerCountDown(for: call)
            nativeCallInterface.reportIncomingCall(uuid: uuid, handleId: userId, localizedName: username) { (error) in
                completion()
            }
            self.log("[CallService] report incoming p2p call from PushKit notification: \(call.debugDescription)")
        } else {
            self.log("[CallService] report failed incoming call from PushKit notification")
            nativeCallInterface.reportImmediateFailureCall()
            completion()
        }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP, registry.pushToken(for: .voIP) == nil else {
            return
        }
        AccountAPI.updateSession(voipToken: voipTokenRemove)
    }
    
}

// MARK: - RTCAudioSessionDelegate
extension CallService: RTCAudioSessionDelegate {
    
    func audioSessionDidBeginInterruption(_ session: RTCAudioSession) {
        if !isUsingCallKit {
            requestEndCall()
        }
    }
    
    func audioSessionDidChangeRoute(_ session: RTCAudioSession, reason: AVAudioSession.RouteChangeReason, previousRoute: AVAudioSessionRouteDescription) {
        let deviceChangedReasons: [AVAudioSession.RouteChangeReason] = [.newDeviceAvailable, .oldDeviceUnavailable]
        let isDeviceChanged = deviceChangedReasons.contains(reason)
        if isDeviceChanged {
            updateAudioSessionConfiguration()
        }
    }
    
}

// MARK: - Workers
extension CallService {
    
    private func beginUnanswerCountDown(for call: Call) {
        guard call.timer == nil else {
            return
        }
        let timer = Timer(timeInterval: callTimeoutInterval,
                          target: self,
                          selector: #selector(self.unansweredTimeout),
                          userInfo: call.uuid,
                          repeats: false)
        RunLoop.main.add(timer, forMode: .default)
        call.timer = timer
    }
    
    @objc private func unansweredTimeout(_ timer: Timer) {
        guard timer.isValid, let uuid = timer.userInfo as? UUID else {
            return
        }
        queue.async {
            timer.invalidate()
            guard let call = self.activeCall ?? self.pendingAnswerCalls[uuid] else {
                return
            }
            guard call.uuid == uuid, call.status == .incoming || call.status == .outgoing else {
                return
            }
            if let call = call as? PeerToPeerCall {
                call.status = .disconnecting
                if call.isOutgoing {
                    let msg = Message.createWebRTCMessage(conversationId: call.conversationId,
                                                          category: .WEBRTC_AUDIO_CANCEL,
                                                          status: .SENDING,
                                                          quoteMessageId: call.uuidString)
                    SendMessageService.shared.sendWebRTCMessage(message: msg,
                                                                recipientId: call.remoteUserId)
                }
                self.insertCallCompletedMessage(call: call,
                                                isUserInitiated: false,
                                                category: .WEBRTC_AUDIO_CANCEL)
            } else if let call = call as? GroupCall, !call.inviters.isEmpty {
                for userId in call.inviters.map(\.userId) {
                    let declining = KrakenRequest(callUUID: call.uuid,
                                                  conversationId: call.conversationId,
                                                  trackId: call.trackId,
                                                  action: .decline(recipientId: userId))
                    KrakenMessageRetriever.shared.request(declining, completion: nil)
                    self.log("[KrakenMessageRetriever] Request \(declining.debugDescription)")
                }
            }
            self.close(uuid: call.uuid)
            DispatchQueue.main.async(execute: self.dismissCallingInterface)
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
        let usesCallKit = !isMainlandChina
            && AVAudioSession.sharedInstance().recordPermission == .granted
        if usesCallKit {
            callInterface = nativeCallInterface
        } else {
            callInterface = MixinCallInterface(service: self)
        }
    }
    
    private func activeOrPendingAnswerCall(with uuid: UUID) -> Call? {
        if let call = activeCall, call.uuid == uuid {
            return call
        } else {
            return pendingAnswerCalls[uuid]
        }
    }
    
    private func updateAudioTrackEnabling() {
        if let audioTrack = rtcClient.audioTrack {
            audioTrack.isEnabled = !isMuted
            self.log("[CallService] isMuted: \(isMuted)")
        } else {
            self.log("[CallService] isMuted: \(isMuted), finds no audio track")
        }
    }
    
    private func updateAudioSessionConfiguration() {
        let usesSpeaker = self.usesSpeaker
        RTCDispatcher.dispatchAsync(on: .typeAudioSession) {
            let session = RTCAudioSession.sharedInstance()
            
            let portTypes = session.currentRoute.outputs.map(\.portType)
            let builtInPortTypes: Set<AVAudioSession.Port> = [.builtInReceiver, .builtInSpeaker]
            let outputContainsBuiltInDevices = portTypes.contains(where: builtInPortTypes.contains)
            
            let category = AVAudioSession.Category.playAndRecord.rawValue
            
            // Without the option of duckOthers, speaker button in system calling interface provided
            // by CallKit will soon becomes off after turning on
            // https://stackoverflow.com/questions/49170274/callkit-loudspeaker-bug-how-whatsapp-fixed-it
            // Every post in the link above👆 is totally gibberish. A default mode gloss over the
            // issue but mess it up when it comes to AirPods
            let options: AVAudioSession.CategoryOptions = [.allowBluetooth, .allowBluetoothA2DP, .duckOthers]
            
            let mode = AVAudioSession.Mode.voiceChat.rawValue
            let audioPort: AVAudioSession.PortOverride = usesSpeaker ? .speaker : .none
            
            let config = RTCAudioSessionConfiguration()
            config.category = category
            config.categoryOptions = options
            config.mode = mode
            
            session.lockForConfiguration()
            defer {
                session.unlockForConfiguration()
            }
            do {
                RTCAudioSessionConfiguration.setWebRTC(config)
                try session.setCategory(category, with: options)
                try session.setMode(mode)
                if outputContainsBuiltInDevices {
                    try session.overrideOutputAudioPort(audioPort)
                } else {
                    try session.overrideOutputAudioPort(.none)
                }
            } catch {
                reporter.report(error: error)
            }
        }
    }
    
    private func beginAutoCancellingBackgroundTaskIfNotActive() {
        let application = UIApplication.shared
        guard application.applicationState != .active else {
            return
        }
        var identifier: UIBackgroundTaskIdentifier = .invalid
        var cancelBackgroundTask: DispatchWorkItem!
        cancelBackgroundTask = DispatchWorkItem {
            if application.applicationState != .active {
                MixinService.isStopProcessMessages = true
                WebSocketService.shared.disconnect()
            }
            if identifier != .invalid {
                application.endBackgroundTask(identifier)
            }
            if let task = cancelBackgroundTask {
                task.cancel()
            }
        }
        identifier = application.beginBackgroundTask {
            cancelBackgroundTask.perform()
        }
        let duration = max(10, min(29, application.backgroundTimeRemaining - 1))
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: cancelBackgroundTask)
    }
    
}

// MARK: - Call Workers
extension CallService {
    
    private func failCurrentCall(sendFailedMessageToRemote: Bool, error: CallError) {
        guard let activeCall = activeCall else {
            self.log("[CallService] fail current call but there's none")
            return
        }
        self.log("[CallService] fail current call: \(sendFailedMessageToRemote), error: \(error)")
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
        } else if let call = activeCall as? GroupCall {
            membersManager.removeMember(with: myUserId, fromConversationWith: call.conversationId)
            if sendFailedMessageToRemote {
                let end = KrakenRequest(callUUID: call.uuid,
                                        conversationId: call.conversationId,
                                        trackId: call.trackId,
                                        action: .end)
                KrakenMessageRetriever.shared.request(end, completion: nil)
                self.log("[KrakenMessageRetriever] Request \(end.debugDescription)")
            }
        }
        close(uuid: activeCall.uuid)
        reporter.report(error: error)
    }
    
    private func requestStartCall(_ call: Call, handle: CXHandle, playOutgoingRingtone: Bool) {
        
        func performRequest() {
            guard activeCall == nil else {
                alert(error: CallError.busy)
                self.log("[CallService] request start call impl reports busy")
                return
            }
            updateCallKitAvailability()
            registerForPushKitNotificationsIfAvailable()
            activeCall = call
            if let call = call as? GroupCall {
                groupCallUUIDs[call.conversationId] = call.uuid
            }
            callInterface.requestStartCall(uuid: call.uuid, handle: handle, playOutgoingRingtone: playOutgoingRingtone) { (error) in
                guard let error = error else {
                    return
                }
                self.activeCall = nil
                if let error = error as? CallError {
                    self.alert(error: error)
                } else {
                    showAutoHiddenHud(style: .error, text: R.string.localizable.chat_message_call_failed())
                }
                self.log("[CallService] request start call impl reports: \(error)")
                reporter.report(error: error)
            }
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { (isGranted) in
            if isGranted {
                self.dispatch(performRequest)
            } else {
                DispatchQueue.main.async {
                    self.alert(error: CallError.microphonePermissionDenied)
                }
            }
        }
        
    }
    
}

// MARK: - Peer-to-Peer Call Workers
extension CallService {
    
    private func startPeerToPeerCall(_ call: PeerToPeerCall, completion: ((Bool) -> Void)?) {
        guard let remoteUser = call.remoteUser ?? UserDAO.shared.getUser(userId: call.remoteUserId) else {
            self.activeCall = nil
            self.alert(error: CallError.missingUser(userId: call.remoteUserId))
            completion?(false)
            return
        }
        call.remoteUser = remoteUser
        DispatchQueue.main.sync {
            self.showCallingInterface(call: call)
        }
        beginUnanswerCountDown(for: call)
        rtcClient.offer(key: nil, withIceRestartConstraint: false) { (result) in
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
    
    private func answer(peerToPeerCall call: PeerToPeerCall, sdp: RTCSessionDescription, completion: ((Bool) -> Void)?) {
        self.activeCall = call
        call.status = .connecting
        DispatchQueue.main.sync {
            self.showCallingInterface(call: call)
        }
        
        for uuid in pendingAnswerCalls.keys {
            endCall(uuid: uuid)
        }
        self.ringtonePlayer.stop()
        self.rtcClient.set(remoteSdp: sdp) { (error) in
            self.handleResultFromSettingRemoteSdpWhenAnsweringPeerToPeerCall(call, error: error, completion: completion)
        }
    }
    
    private func handleResultFromSettingRemoteSdpWhenAnsweringPeerToPeerCall(_ call: PeerToPeerCall, error: Error?, completion: ((Bool) -> Void)?) {
        if let error = error {
            self.failCurrentCall(sendFailedMessageToRemote: true,
                                 error: .setRemoteSdp(error))
            completion?(false)
        } else {
            self.rtcClient.answer(completion: { result in
                switch result {
                case .success(let sdpJson):
                    self.log("[CallService] Sending answer")
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

// MARK: - Group Call Workers
extension CallService {
    
    private typealias SdpResult = Result<(trackId: String, sdp: RTCSessionDescription), CallError>
    
    private func request(_ request: KrakenRequest, completion: @escaping (SdpResult) -> Void) {
        self.log("[KrakenMessageRetriever] Request \(request.debugDescription)")
        KrakenMessageRetriever.shared.request(request) { (result) in
            switch result {
            case .success(let data):
                guard let responseData = Data(base64Encoded: data.data) else {
                    self.log("[KrakenMessageRetriever] invalid response data: \(data.data)")
                    completion(.failure(.invalidKrakenResponse))
                    return
                }
                guard let data = try? JSONDecoder.default.decode(KrakenPublishResponse.self, from: responseData) else {
                    self.log("[KrakenMessageRetriever] invalid KrakenPublishResponse: \(String(data: responseData, encoding: .utf8))")
                    completion(.failure(.invalidKrakenResponse))
                    return
                }
                guard let sdpJson = data.jsep.base64Decoded(), let sdp = RTCSessionDescription(jsonString: sdpJson) else {
                    self.log("[KrakenMessageRetriever] invalid JSEP: \(data.jsep)")
                    completion(.failure(.invalidKrakenResponse))
                    return
                }
                completion(.success((data.trackId, sdp)))
            case let .failure(error):
                switch error {
                case MixinAPIError.roomFull:
                    completion(.failure(.roomFull))
                case MixinAPIError.peerNotFound, MixinAPIError.peerClosed, MixinAPIError.trackNotFound:
                    completion(.failure(.invalidPeerConnection(error as! MixinAPIError)))
                default:
                    completion(.failure(.networkFailure))
                }
            }
        }
    }
    
    // Call this func on backend error
    private func restartCurrentGroupCall() {
        guard let call = activeCall as? GroupCall else {
            return
        }
        self.log("[CallService] restart Current GroupCall \(call.debugDescription)")
        call.frameKey = nil
        rtcClient.close()
        pendingTrickles.removeValue(forKey: call.uuid)
        startGroupCall(call, isRestarting: false) { (success) in
            if !success {
                self.log("[CallService] failed to restart \(call.debugDescription), will restart again")
                self.restartCurrentGroupCall()
            }
        }
        
        // Disable audio track if muted since audio track is replaced with a new one
        updateAudioTrackEnabling()
    }
    
    // Call this func for a new initiated call, or on ICE Connection reports failure
    private func startGroupCall(_ call: GroupCall, isRestarting: Bool, completion: ((Bool) -> Void)?) {
        self.log("[CallService] start group call impl \(call.debugDescription), isRestarting: \(isRestarting)")
        DispatchQueue.main.sync {
            self.showCallingInterface(call: call)
        }
        let frameKey: Data?
        if isRestarting {
            if let key = call.frameKey {
                frameKey = key
            } else {
                completion?(false)
                return
            }
        } else {
            try? ReceiveMessageService.shared.checkSessionSenderKey(conversationId: call.conversationId)
            frameKey = SignalProtocol.shared.getSenderKeyPublic(groupId: call.conversationId, userId: myUserId)?.dropFirst()
            call.frameKey = frameKey
        }
        self.log("[CallService] start group call impl, framekey: \(frameKey)")
        beginUnanswerCountDown(for: call)
        rtcClient.offer(key: frameKey, withIceRestartConstraint: isRestarting) { result in
            switch result {
            case .success(let sdp):
                self.publish(sdp: sdp, to: call, isRestarting: isRestarting, completion: completion)
            case .failure(let error):
                self.log("[CallService] start group call impl got error: \(error)")
                self.failCurrentCall(sendFailedMessageToRemote: false, error: error)
                if call.status != .disconnecting {
                    self.alert(error: CallError.offerConstruction(error))
                }
                completion?(false)
            }
        }
    }
    
    private func publish(sdp: String, to call: GroupCall, isRestarting: Bool, completion: ((Bool) -> Void)?) {
        let action: KrakenRequest.Action = isRestarting ? .restart(sdp: sdp) : .publish(sdp: sdp)
        let publishing = KrakenRequest(callUUID: call.uuid,
                                       conversationId: call.conversationId,
                                       trackId: call.trackId,
                                       action: action)
        request(publishing) { (result) in
            switch result {
            case let .success((trackId, sdp)):
                self.handlePublishingResponse(to: call, trackId: trackId, sdp: sdp, completion: completion)
            case let .failure(error):
                if case let .invalidPeerConnection(code) = error {
                    completion?(true)
                    self.log("[CallService] Got invalid peer connection \(code), try to restart")
                    self.restartCurrentGroupCall()
                } else {
                    self.log("[CallService] publish failed for invalid response: \(error)")
                    self.failCurrentCall(sendFailedMessageToRemote: true, error: error)
                    self.callInterface.reportCall(uuid: call.uuid, endedByReason: .failed)
                    self.alert(error: error)
                    completion?(false)
                }
            }
        }
    }
    
    private func handlePublishingResponse(to call: GroupCall, trackId: String, sdp: RTCSessionDescription, completion: ((Bool) -> Void)?) {
        NotificationCenter.default.addObserver(self, selector: #selector(senderKeyChange(_:)), name: ReceiveMessageService.senderKeyDidChangeNotification, object: nil)
        call.trackId = trackId
        if call.isOutgoing {
            callInterface.reportOutgoingCallStartedConnecting(uuid: call.uuid)
            call.invitePendingUsers()
        }
        rtcClient.set(remoteSdp: sdp) { (error) in
            if let error = error {
                self.log("[CallService] group call publish impl set sdp from publishing response failed: \(error)")
                let end = KrakenRequest(callUUID: call.uuid,
                                        conversationId: call.conversationId,
                                        trackId: trackId,
                                        action: .end)
                KrakenMessageRetriever.shared.request(end, completion: nil)
                self.log("[KrakenMessageRetriever] Request \(end.debugDescription)")
                if call.status != .disconnecting {
                    self.alert(error: CallError.setRemoteAnswer(error))
                }
                self.close(uuid: call.uuid)
                completion?(false)
            } else {
                completion?(true)
                self.log("[CallService] group call successfully set sdp from publishing response")
                self.queue.async {
                    self.subscribe(userId: myUserId, of: call)
                    self.pendingTrickles.removeValue(forKey: call.uuid)?.forEach({ (candidate) in
                        let trickle = KrakenRequest(callUUID: call.uuid,
                                                    conversationId: call.conversationId,
                                                    trackId: trackId,
                                                    action: .trickle(candidate: candidate))
                        KrakenMessageRetriever.shared.request(trickle, completion: nil)
                        self.log("[KrakenMessageRetriever] Request \(trickle.debugDescription)")
                    })
                }
            }
        }
    }
    
    private func subscribe(userId: String, of call: GroupCall) {
        let subscribing = KrakenRequest(callUUID: call.uuid,
                                        conversationId: call.conversationId,
                                        trackId: call.trackId,
                                        action: .subscribe)
        self.log("[CallService] subscribe is sent")
        request(subscribing) { (result) in
            switch result {
            case let .success((_, sdp)) where sdp.type == .offer:
                self.log("[CallService] setting sdp from subscribe response")
                self.rtcClient.set(remoteSdp: sdp) { (error) in
                    if let error = error {
                        reporter.report(error: error)
                        self.log("[CallService] subscribe failed to setting sdp: \(error)")
                        self.queue.asyncAfter(deadline: .now() + self.retryInterval) {
                            guard self.activeCall == call, call.status != .disconnecting else {
                                return
                            }
                            self.subscribe(userId: userId, of: call)
                        }
                    } else {
                        self.log("[CallService] successfully set sdp from subscribe response")
                        self.answer(userId: userId, of: call)
                    }
                }
            case .success:
                self.log("[CallService] dropping subscribing result for non-offer sdp")
            case .failure(let error):
                switch error {
                case .invalidKrakenResponse:
                    self.log("[CallService] dropping subscribing result for invalid response")
                case .invalidPeerConnection:
                    self.log("[CallService] dropping subscribing result and restart the call")
                    self.restartCurrentGroupCall()
                default:
                    self.log("[CallService] subscribing result reports \(error)")
                    self.alert(error: error)
                    self.failCurrentCall(sendFailedMessageToRemote: true, error: error)
                    self.callInterface.reportCall(uuid: call.uuid, endedByReason: .failed)
                }
            }
        }
    }
    
    private func answer(userId: String, of call: GroupCall) {
        rtcClient.answer { (result) in
            switch result {
            case .success(let sdpJson):
                let answer = KrakenRequest(callUUID: call.uuid,
                                           conversationId: call.conversationId,
                                           trackId: call.trackId,
                                           action: .answer(sdp: sdpJson))
                KrakenMessageRetriever.shared.request(answer, completion: nil)
                self.log("[KrakenMessageRetriever] Request \(answer.debugDescription)")
            case .failure(let error):
                self.log("[CallService] group call answer failed setting sdp: \(error)")
                reporter.report(error: error)
                self.queue.asyncAfter(deadline: .now() + self.retryInterval) {
                    guard self.activeCall == call, call.status != .disconnecting else {
                        return
                    }
                    self.answer(userId: userId, of: call)
                }
            }
        }
    }
    
    @objc private func senderKeyChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo else {
            return
        }
        guard let conversationId = userInfo[ReceiveMessageService.UserInfoKey.conversationId] as? String else {
            return
        }
        queue.async {
            guard let call = self.activeCall as? GroupCall, call.conversationId == conversationId else {
                self.log("[CallService] sender key changed but there's no active call has same conversation id")
                return
            }
            self.log("[CallService] sender key is updated")
            let userId = userInfo[ReceiveMessageService.UserInfoKey.userId] as? String
            let sessionId = userInfo[ReceiveMessageService.UserInfoKey.sessionId] as? String
            if let userId = userId, let sessionId = sessionId, !userId.isEmpty && !sessionId.isEmpty {
                let userIds = self.membersManager.members[conversationId] ?? [] // Since there's an active call it won't be nil
                if userIds.contains(userId) {
                    let frameKey = SignalProtocol.shared.getSenderKeyPublic(groupId: conversationId, userId: userId)
                    self.rtcClient.setFrameDecryptorKey(frameKey, forReceiverWith: userId, sessionId: sessionId)
                }
            } else if let userId = userId, !userId.isEmpty {
                try? ReceiveMessageService.shared.checkSessionSenderKey(conversationId: call.conversationId)
            } else {
                try? ReceiveMessageService.shared.checkSessionSenderKey(conversationId: call.conversationId)
                let frameKey = SignalProtocol.shared.getSenderKeyPublic(groupId: conversationId, userId: myUserId)
                self.rtcClient.setFrameEncryptorKey(frameKey)
            }
        }
    }
    
}
