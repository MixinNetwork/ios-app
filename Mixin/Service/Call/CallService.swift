import Foundation
import PushKit
import CallKit
import WebRTC
import MixinServices

class CallService: NSObject {
    
    static let shared = CallService()
    static let mutenessDidChangeNotification = Notification.Name("one.mixin.messenger.CallService.MutenessDidChange")
    static let willActivateCallNotification = Notification.Name("one.mixin.messenger.CallService.WillActivateCall")
    static let willDeactivateCallNotification = Notification.Name("one.mixin.messenger.CallService.WillDeactivateCall")
    static let callUserInfoKey = "call"
    
    let queue = DispatchQueue(label: "one.mixin.messenger.CallService")
    
    var isMuted = false {
        didSet {
            NotificationCenter.default.postOnMain(name: Self.mutenessDidChangeNotification)
            if let audioTrack = rtcClient.audioTrack {
                audioTrack.isEnabled = !isMuted
                self.log("[CallService] isMuted: \(isMuted)")
            } else {
                self.log("[CallService] isMuted: \(isMuted), finds no audio track")
            }
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
        return mediaDurationFormatter.string(from: duration)
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
    private lazy var mixinCallInterface = MixinCallInterface(service: self)
    
    private var usesCallKit = false // Access from CallService.queue
    private var pushRegistry: PKPushRegistry?
    
    private var pendingAnswerCalls = [UUID: Call]()
    private var pendingSDPs = [UUID: RTCSessionDescription]()
    private var pendingCandidates = [UUID: [RTCIceCandidate]]()
    private var pendingTrickles = [UUID: [String]]() // Key is Call's UUID, Value is array of candidate string
    private var listPendingCallWorkItems = [UUID: DispatchWorkItem]()
    
    private var window: CallWindow?
    private var viewController: CallViewController?
    
    private weak var unansweredTimer: Timer?
    
    // Access from CallService.queue
    private var callInterface: CallInterface {
        if usesCallKit {
            self.log("[CallService] using native call interface")
        } else {
            self.log("[CallService] using mixin call interface")
        }
        return usesCallKit ? nativeCallInterface : mixinCallInterface
    }
    
    override init() {
        super.init()
        queue.setSpecific(key: queueSpecificKey, value: ())
        rtcClient.delegate = self
        updateCallKitAvailability()
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
    
    func alert(error: CallError) {
        let content = error.alertContent
        DispatchQueue.main.async {
            guard let controller = AppDelegate.current.mainWindow.rootViewController else {
                return
            }
            if case .microphonePermissionDenied = error {
                controller.alertSettings(content)
            } else {
                controller.alert(content)
            }
        }
    }
    
    func log(_ log: String) {
        NSLog(log)
        Logger.write(log: log)
    }
    
}

// MARK: - Calling Interface
extension CallService {
    
    func requestStartPeerToPeerCall(remoteUser: UserItem) {
        self.log("[CallService] Request start p2p call with user: \(remoteUser.fullName)")
        let handle = CXHandle(type: .generic, value: remoteUser.userId)
        requestStartCall(handle: handle, playOutgoingRingtone: true, makeCall: { uuid in
            PeerToPeerCall(uuid: uuid, isOutgoing: true, remoteUser: remoteUser)
        })
    }
    
    func requestStartGroupCall(conversation: ConversationItem, invitingMembers: [UserItem]) {
        self.log("[CallService] Request start p2p call with conversation: \(conversation.getConversationName())")
        let handle = CXHandle(type: .generic, value: conversation.conversationId)
        requestStartCall(handle: handle, playOutgoingRingtone: false, makeCall: { uuid in
            var members = self.membersManager.members(inConversationWith: conversation.conversationId)
            if let account = LoginManager.shared.account {
                let me = UserItem.createUser(from: account)
                members.append(me)
            }
            self.log("[CallService] Making call with members: \(members.map(\.fullName))")
            let call = GroupCall(uuid: uuid,
                                 isOutgoing: true,
                                 conversation: conversation,
                                 members: members,
                                 invitingMembers: invitingMembers)
            call.status = .outgoing
            return call
        })
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
    
    func dismissCallingInterface() {
        AppDelegate.current.mainWindow.makeKeyAndVisible()
        if let container = UIApplication.homeContainerViewController {
            container.minimizedCallViewControllerIfLoaded?.view.alpha = 0
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
                self.alert(error: .networkFailure)
                completion?(false)
                return
            }
            if let call = self.activeCall as? PeerToPeerCall, call.remoteUserId == handle.value {
                self.startPeerToPeerCall(call, completion: completion)
                self.log("[CallService] start p2p call")
            } else if let call = self.activeCall as? GroupCall, call.uuid == uuid {
                DispatchQueue.main.sync {
                    self.showCallingInterface(call: call)
                }
                self.startGroupCall(call, completion: completion)
                self.log("[CallService] start group call")
            } else {
                self.alert(error: .inconsistentCallStarted)
                self.log("[CallService] inconsistentCallStarted")
                completion?(false)
            }
        }
    }
    
    func answerCall(uuid: UUID, completion: ((Bool) -> Void)?) {
        dispatch {
            if let call = self.pendingAnswerCalls[uuid] as? PeerToPeerCall, let sdp = self.pendingSDPs[uuid] {
                self.log("[CallService] answer p2p call: \(call.debugDescription)")
                self.pendingAnswerCalls.removeValue(forKey: uuid)
                self.pendingSDPs.removeValue(forKey: uuid)
                self.answer(peerToPeerCall: call, sdp: sdp, completion: completion)
            } else if let call = self.pendingAnswerCalls[uuid] as? GroupCall {
                self.log("[CallService] answer group call: \(call.debugDescription)")
                self.pendingAnswerCalls.removeValue(forKey: uuid)
                self.activeCall = call
                self.ringtonePlayer.stop()
                call.status = .connecting
                DispatchQueue.main.sync {
                    self.showCallingInterface(call: call)
                }
                self.startGroupCall(call, completion: completion)
            } else {
                self.log("[CallService] answer call with: \(uuid) but there's nothting")
            }
        }
    }
    
    func endCall(uuid: UUID) {
        dispatch {
            DispatchQueue.main.sync(execute: self.beginAutoCancellingBackgroundTaskIfNotActive)
            if let call = (self.pendingAnswerCalls[uuid] ?? self.activeCall), call.uuid == uuid {
                let callStatusWasIncoming = call.status == .incoming
                call.status = .disconnecting
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
                    self.membersManager.removeMember(with: myUserId, fromConversationWith: call.conversationId)
                }
            }
            self.close(uuid: uuid)
        }
    }
    
    func closeAll() {
        self.log("[CallService] close all call")
        activeCall = nil
        rtcClient.close()
        unansweredTimer?.invalidate()
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
        if !usesCallKit {
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
            if call.isOutgoing {
                unansweredTimer?.invalidate()
            }
        }
        pendingAnswerCalls.removeValue(forKey: uuid)
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
            if !usesCallKit {
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
            case .KRAKEN_END, .KRAKEN_DECLINE:
                self.handleKrakenDisconnect(data: data)
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

// MARK: - Kraken response handlers
extension CallService {
    
    private func handlePublishing(data: BlazeMessageData) {
        self.log("[CallService] Got publish from: \(data.userId)")
        membersManager.addMember(with: data.userId, toConversationWith: data.conversationId)
        let groupCall: GroupCall?
        if let call = activeCall as? GroupCall, call.conversationId == data.conversationId {
            groupCall = call
            subscribe(userId: data.userId, of: call)
        } else if let uuid = UUID(uuidString: data.conversationId) {
            groupCall = pendingAnswerCalls[uuid] as? GroupCall
        } else {
            groupCall = nil
        }
        if let call = groupCall {
            call.reportMemberWithIdDidConnected(data.userId)
        }
    }
    
    private func handleInvitation(data: BlazeMessageData) {
        do {
            DispatchQueue.main.sync(execute: beginAutoCancellingBackgroundTaskIfNotActive)
            self.log("[CallService] Got Invitation from: \(data.userId)")
            guard let uuid = UUID(uuidString: data.conversationId) else {
                self.log("[CallService] invalid conversation id: \(data.conversationId)")
                return
            }
            guard let conversation = ConversationDAO.shared.getConversation(conversationId: data.conversationId) else {
                self.log("[CallService] no conversation: \(data.conversationId)")
                return
            }
            AudioManager.shared.pause()
            var members = membersManager.members(inConversationWith: data.conversationId)
            if let account = LoginManager.shared.account {
                let me = UserItem.createUser(from: account)
                members.append(me)
            }
            let call = GroupCall(uuid: uuid,
                                 isOutgoing: false,
                                 conversation: conversation,
                                 members: members,
                                 invitingMembers: [])
            call.status = .incoming
            call.inviterUserId = data.userId
            self.log("[CallService] reporting incoming group call invitation: \(call.debugDescription)")
            pendingAnswerCalls[uuid] = call
            callInterface.reportIncomingCall(call) { (error) in
                guard let error = error else {
                    return
                }
                self.log("[CallService] incoming call reporting error: \(error)")
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
    
    private func handleKrakenDisconnect(data: BlazeMessageData) {
        self.log("[CallService] Got \(data.category), report member: \(data.userId) disconnected")
        membersManager.removeMember(with: data.userId,
                                    fromConversationWith: data.conversationId)
        if let call = activeCall as? GroupCall {
            call.reportMemberWithIdDidDisconnected(data.userId)
        }
    }
    
    private func handleKrakenCancel(data: BlazeMessageData) {
        self.log("[CallService] Got kraken cancel from \(data.userId)")
        guard let uuid = UUID(uuidString: data.conversationId) else {
            self.log("[CallService] invalid conversation id: \(data.conversationId)")
            return
        }
        guard let call = activeCall ?? pendingAnswerCalls.removeValue(forKey: uuid) else {
            self.log("[CallService] no such call: \(uuid)")
            return
        }
        guard call.uuid == uuid, call.status == .incoming else {
            return
        }
        self.log("[CallService] cancel call: \(uuid)")
        call.status = .disconnecting
        callInterface.reportCall(uuid: uuid, endedByReason: .remoteEnded)
        close(uuid: uuid)
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
                let request = KrakenRequest(conversationId: call.conversationId,
                                            trackId: trackId,
                                            action: .trickle(candidate: json))
                SendMessageService.shared.send(krakenRequest: request)
            } else {
                var trickles = pendingTrickles[call.uuid] ?? []
                trickles.append(json)
                pendingTrickles[call.uuid] = trickles
            }
        }
    }
    
    func webRTCClientDidConnected(_ client: WebRTCClient) {
        guard let call = activeCall, call.connectedDate == nil else {
            self.log("[CallService] RTC connected, activeCall: \(activeCall)")
            return
        }
        self.log("[CallService] RTC connected, reporting with: \(call.debugDescription)")
        let date = Date()
        call.connectedDate = date
        if call.isOutgoing {
            callInterface.reportOutgoingCall(uuid: call.uuid, connectedAtDate: date)
        } else {
            callInterface.reportIncomingCall(uuid: call.uuid, connectedAtDate: date)
        }
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        call.status = .connected
        updateAudioSessionConfiguration()
        if !usesCallKit {
            RTCDispatcher.dispatchAsync(on: .typeAudioSession) {
                RTCAudioSession.sharedInstance().isAudioEnabled = true
            }
        }
    }
    
    func webRTCClientDidDisconnected(_ client: WebRTCClient) {
        self.log("[CallService] RTC Disconnected")
        if let call = activeCall {
            callInterface.reportCall(uuid: call.uuid, endedByReason: .failed)
            if call is GroupCall {
                failCurrentCall(sendFailedMessageToRemote: true, error: .clientFailure)
            }
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
        guard let userId = payload.dictionaryPayload["user_id"] as? String, let name = payload.dictionaryPayload["name"] as? String else {
            nativeCallInterface.reportImmediateFailureCall()
            completion()
            return
        }
        DispatchQueue.main.async {
            self.beginAutoCancellingBackgroundTaskIfNotActive()
            MixinService.isStopProcessMessages = false
            WebSocketService.shared.connectIfNeeded()
        }
        if usesCallKit, !name.isEmpty, let conversationId = payload.dictionaryPayload["conversation_id"] as? String, let uuid = UUID(uuidString: conversationId), let conversation = ConversationDAO.shared.getConversation(conversationId: conversationId) {
            let members = self.membersManager.members(inConversationWith: conversationId)
            let call = GroupCall(uuid: uuid,
                                 isOutgoing: false,
                                 conversation: conversation,
                                 members: members,
                                 invitingMembers: [])
            call.status = .incoming
            call.inviterUserId = userId
            pendingAnswerCalls[uuid] = call
            nativeCallInterface.reportIncomingCall(uuid: uuid, handleId: conversationId, localizedName: name) { (error) in
                completion()
            }
            self.log("[CallService] report incoming group call from PushKit notification: \(call.debugDescription)")
        } else if usesCallKit, let messageId = payload.dictionaryPayload["message_id"] as? String, !MessageDAO.shared.isExist(messageId: messageId), let uuid = UUID(uuidString: messageId), let username = payload.dictionaryPayload["full_name"] as? String {
            let call = PeerToPeerCall(uuid: uuid, isOutgoing: false, remoteUserId: userId, remoteUsername: username)
            pendingAnswerCalls[uuid] = call
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
        AccountAPI.shared.updateSession(voipToken: voipTokenRemove)
    }
    
}

// MARK: - Workers
extension CallService {
    
    @objc private func unansweredTimeout() {
        guard let call = activeCall as? PeerToPeerCall, call.isOutgoing, !call.hasReceivedRemoteAnswer else {
            return
        }
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
    
    private func dispatch(_ closure: @escaping () -> Void) {
        if DispatchQueue.getSpecific(key: queueSpecificKey) == nil {
            queue.async(execute: closure)
        } else {
            closure()
        }
    }
    
    private func updateCallKitAvailability() {
        usesCallKit = !isMainlandChina && AVAudioSession.sharedInstance().recordPermission == .granted
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
                let request = KrakenRequest(conversationId: call.conversationId,
                                            trackId: call.trackId,
                                            action: .end)
                SendMessageService.shared.send(krakenRequest: request)
            }
            let msg = Message.createKrakenStatusMessage(category: .KRAKEN_END,
                                                        conversationId: call.conversationId,
                                                        userId: "")
            MessageDAO.shared.insertMessage(message: msg, messageSource: "")
        }
        close(uuid: activeCall.uuid)
        reporter.report(error: error)
    }
    
    private func requestStartCall(handle: CXHandle, playOutgoingRingtone: Bool, makeCall: @escaping (UUID) -> Call) {
        
        func performRequest() {
            guard activeCall == nil else {
                alert(error: .busy)
                self.log("[CallService] request start call impl reports busy")
                return
            }
            updateCallKitAvailability()
            registerForPushKitNotificationsIfAvailable()
            let uuid = UUID()
            let call = makeCall(uuid)
            activeCall = call
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
                    self.alert(error: .microphonePermissionDenied)
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
    
}

// MARK: - Group Call Workers
extension CallService {
    
    private func send(krakenRequest: KrakenRequest) -> (trackId: String, sdp: RTCSessionDescription)? {
        guard let response = SendMessageService.shared.send(krakenRequest: krakenRequest) else {
            return nil
        }
        guard let responseData = Data(base64Encoded: response.data) else {
            return nil
        }
        guard let data = try? JSONDecoder.default.decode(KrakenPublishResponse.self, from: responseData) else {
            return nil
        }
        guard let sdpJson = data.jsep.base64Decoded(), let sdp = RTCSessionDescription(jsonString: sdpJson) else {
            return nil
        }
        return (data.trackId, sdp)
    }
    
    private func startGroupCall(_ call: GroupCall, completion: ((Bool) -> Void)?) {
        self.log("[CallService] start group call impl \(call.debugDescription)")
        try? ReceiveMessageService.shared.checkSessionSenderKey(conversationId: call.conversationId)
        let frameKey = SignalProtocol.shared.getSenderKeyPublic(groupId: call.conversationId, userId: myUserId)?.dropFirst()
        self.log("[CallService] start group call impl framekey: \(frameKey)")
        rtcClient.offer(key: frameKey) { clientResult in
            var result = clientResult
            #if DEBUG
            if GroupCallDebugConfig.throwErrorOnOfferGeneration {
                result = .failure(.manuallyInitiated)
            }
            #endif
            switch result {
            case .failure(let error):
                self.log("[CallService] start group call impl got error: \(error)")
                self.failCurrentCall(sendFailedMessageToRemote: false, error: error)
                self.alert(error: .offerConstruction(error))
                completion?(false)
            case .success(let sdp):
                self.publish(sdp: sdp, to: call, completion: completion)
            }
        }
    }
    
    private func publish(sdp: String, to call: GroupCall, completion: ((Bool) -> Void)?) {
        let publishing = KrakenRequest(conversationId: call.conversationId,
                                       trackId: nil,
                                       action: .publish(sdp: sdp))
        self.log("[CallService] group call publish is sent")
        guard let (trackId, sdp) = send(krakenRequest: publishing) else {
            self.log("[CallService] publish failed for nil response")
            failCurrentCall(sendFailedMessageToRemote: true, error: .invalidKrakenResponse)
            alert(error: .invalidKrakenResponse)
            completion?(false)
            return
        }
        NotificationCenter.default.addObserver(self, selector: #selector(senderKeyChange(_:)), name: ReceiveMessageService.senderKeyDidChangeNotification, object: nil)
        #if DEBUG
        if GroupCallDebugConfig.invalidResponseOnPublishing {
            failCurrentCall(sendFailedMessageToRemote: true, error: .invalidKrakenResponse)
            alert(error: .invalidKrakenResponse)
            completion?(false)
            return
        }
        #endif
        call.trackId = trackId
        if call.isOutgoing {
            callInterface.reportOutgoingCallStartedConnecting(uuid: call.uuid)
        }
        rtcClient.set(remoteSdp: sdp) { (clientError) in
            var error = clientError
            #if DEBUG
            if GroupCallDebugConfig.throwOnSettingSdpFromPublishingResponse {
                error = CallError.manuallyInitiated
            }
            #endif
            if let error = error {
                self.log("[CallService] group call publish impl set sdp from publishing response failed: \(error)")
                let end = KrakenRequest(conversationId: call.conversationId,
                                        trackId: trackId,
                                        action: .end)
                SendMessageService.shared.send(krakenRequest: end)
                self.close(uuid: call.uuid)
                self.alert(error: .setRemoteAnswer(error))
                completion?(false)
            } else {
                completion?(true)
                self.log("[CallService] group call successfully set sdp from publishing response")
                self.queue.async {
                    self.subscribe(userId: myUserId, of: call)
                    self.pendingTrickles.removeValue(forKey: call.uuid)?.forEach({ (candidate) in
                        let trickle = KrakenRequest(conversationId: call.conversationId,
                                                    trackId: trackId,
                                                    action: .trickle(candidate: candidate))
                        SendMessageService.shared.send(krakenRequest: trickle)
                    })
                    if call.isOutgoing {
                        call.invitePendingUsers()
                    }
                }
            }
        }
    }
    
    private func subscribe(userId: String, of call: GroupCall) {
        let subscribing = KrakenRequest(conversationId: call.conversationId,
                                        trackId: call.trackId,
                                        action: .subscribe)
        self.log("[CallService] subscribe is sent")
        guard let (_, sdp) = send(krakenRequest: subscribing), sdp.type == .offer else {
            self.log("[CallService] subscribe impl ends for invalid response")
            return
        }
        self.log("[CallService] setting sdp from subscribe response")
        rtcClient.set(remoteSdp: sdp) { (clientError) in
            var error = clientError
            #if DEBUG
            if GroupCallDebugConfig.throwErrorOnSettingSdpFromSubscribingResponse {
                error = CallError.manuallyInitiated
            }
            #endif
            if let error = error {
                reporter.report(error: error)
                self.log("[CallService] subscribe failed to setting sdp: \(error)")
                // TODO: An local error happened on subscribing, does retrying like below making sense?
                self.queue.asyncAfter(deadline: .now() + self.retryInterval) {
                    guard self.activeCall == call else {
                        return
                    }
                    self.subscribe(userId: userId, of: call)
                }
            } else {
                self.log("[CallService] successfully set sdp from subscribe response")
                self.answer(userId: userId, of: call)
            }
        }
    }
    
    private func answer(userId: String, of call: GroupCall) {
        rtcClient.answer { (clientResult) in
            var result = clientResult
            #if DEBUG
            if GroupCallDebugConfig.throwErrorOnAnswerGeneration {
                result = .failure(.manuallyInitiated)
            }
            #endif
            switch result {
            case .success(let sdpJson):
                let answer = KrakenRequest(conversationId: call.conversationId,
                                           trackId: call.trackId,
                                           action: .answer(sdp: sdpJson))
                SendMessageService.shared.send(krakenRequest: answer)
                self.log("[CallService] group call answer is sent")
            case .failure(let error):
                self.log("[CallService] group call answer failed setting sdp: \(error)")
                reporter.report(error: error)
                // TODO: An local error happened on subscribing, does retrying like below making sense?
                self.queue.asyncAfter(deadline: .now() + self.retryInterval) {
                    guard self.activeCall == call else {
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
            if let userId = userInfo[ReceiveMessageService.UserInfoKey.userId] as? String, let sessionId = userInfo[ReceiveMessageService.UserInfoKey.sessionId] as? String, !userId.isEmpty && !sessionId.isEmpty {
                let userIds = self.membersManager.members[conversationId] ?? [] // Since there's an active call it won't be nil
                if userIds.contains(userId) {
                    let frameKey = SignalProtocol.shared.getSenderKeyPublic(groupId: conversationId, userId: userId)
                    self.rtcClient.setFrameDecryptorKey(frameKey, forReceiverWith: userId, sessionId: sessionId)
                }
            } else {
                try? ReceiveMessageService.shared.checkSessionSenderKey(conversationId: call.conversationId)
                let frameKey = SignalProtocol.shared.getSenderKeyPublic(groupId: conversationId, userId: myUserId)
                self.rtcClient.setFrameEncryptorKey(frameKey)
            }
        }
    }
    
}
