import Foundation
import AVFoundation
import PushKit
import CallKit
import WebRTC
import MixinServices

fileprivate let isCallKitForbidden = false
fileprivate let listPendingMessageDelay: DispatchTimeInterval = .seconds(2)

class CallService: NSObject {
    
    enum AudioOutput {
        case builtInReceiver
        case builtInSpeaker
        case other
    }
    
    static let shared = CallService()
    static let didActivateCallNotification = Notification.Name("one.mixin.messenger.CallService.DidActivateCall")
    static let didDeactivateCallNotification = Notification.Name("one.mixin.messenger.CallService.DidDeactivateCall")
    static let audioOutputDidChangeNotification = Notification.Name("one.mixin.messenger.CallService.AudioOutputDidChange")
    static let callUserInfoKey = "call"
    
    let membersManager = GroupCallMembersManager()
    
    var isWebRTCLogEnabled = false {
        didSet {
            if isWebRTCLogEnabled {
                if rtcFileLogger == nil {
                    RTCSetMinDebugLogLevel(.warning)
                    let logger = RTCFileLogger(dirPath: AppGroupContainer.webRTCLogURL.path,
                                               maxFileSize: 2 * bytesPerMegaByte,
                                               rotationType: .typeApp)
                    logger.severity = .warning
                    logger.start()
                    rtcFileLogger = logger
                }
            } else {
                if let logger = rtcFileLogger {
                    RTCSetMinDebugLogLevel(.none)
                    logger.stop()
                    rtcFileLogger = nil
                }
            }
        }
    }
    
    private(set) var isInterfaceMinimized = false
    private(set) var audioOutput: AudioOutput = .builtInReceiver
    
    // If PushKit is not registered, call notification is delivered with UserNotification
    // That will be annoying if app is active, or user has already chose to pick or decline
    // the call. Save any handled offer/invitation uuid here, user notifications will not
    // present after then. See NotificationManager's
    // [userNotificationCenter:willPresentNotification:withCompletionHandler:] for details.
    // Access on main queue
    private(set) var handledUUIDs: Set<UUID> = []
    
    private(set) var calls: [UUID: Call] = [:]
    private(set) var activeCall: Call? {
        didSet {
            assert(Thread.isMainThread)
            if let deactivatedCall = oldValue {
                NotificationCenter.default.post(name: Self.didDeactivateCallNotification,
                                                object: self,
                                                userInfo: [Self.callUserInfoKey: deactivatedCall])
            }
            if let call = activeCall {
                NotificationCenter.default.post(name: Self.didActivateCallNotification,
                                                object: self,
                                                userInfo: [Self.callUserInfoKey: call])
            }
        }
    }
    
    private let ringtonePlayer = RingtonePlayer()
    private let blazeProcessingQueue = DispatchQueue(label: "one.mixin.messenger.CallService.BlazeProcessing")
    
    private lazy var callKitAdapter = CallKitAdapter(service: self)
    
    private var adapter: CallAdapter!
    private var rtcFileLogger: RTCFileLogger?
    private var pushRegistry: PKPushRegistry?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var viewController: CallViewController?
    
    // CallKit identify a call with an *unique* UUID, any duplication will cause undocumented behavior
    // Since there's no unique id provided by backend, but only one call is allowed per-conversation,
    // We map conversation id to call's uuid here
    private var groupCallUUIDs: [String: UUID] = [:]
    
    // Access these 2 on blazeProcessingQueue
    private var listPendingWorkItems: [UUID: DispatchWorkItem] = [:]
    private var listPendingCandidates: [UUID: [BlazeMessageData]] = [:]
    
    var hasCall: Bool {
        assert(Thread.isMainThread)
        return activeCall != nil || !calls.isEmpty
    }
    
    override init() {
        super.init()
        reloadCallAdapter()
        RTCAudioSession.sharedInstance().add(self)
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(callStateDidChange(_:)),
                           name: Call.stateDidChangeNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(callDidEnd(_:)),
                           name: Call.didEndNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(callDidUpdateLocalizedName(_:)),
                           name: Call.localizedNameDidUpdateNotification,
                           object: nil)
    }
    
    func registerForPushKitNotificationsIfAvailable() {
        assert(Thread.isMainThread)
        guard self.pushRegistry == nil else {
            return
        }
        guard adapter is CallKitAdapter else {
            AccountAPI.updateSession(voipToken: .remove)
            Logger.call.info(category: "CallService", message: "PushKit invalidated")
            return
        }
        let registry = PKPushRegistry(queue: .main)
        registry.desiredPushTypes = [.voIP]
        registry.delegate = self
        if let token = registry.pushToken(for: .voIP)?.toHexString() {
            AccountAPI.updateSession(voipToken: .token(token))
            Logger.call.info(category: "CallService", message: "PushKit registered")
        }
        self.pushRegistry = registry
    }
    
    func handlePendingWebRTCJobs() {
        let jobs = JobDAO.shared.nextBatchJobs(category: .Task, action: .PENDING_WEBRTC, limit: nil)
        for job in jobs {
            let data = job.toBlazeMessageData()
            let isOffer = data.category == MessageCategory.WEBRTC_AUDIO_OFFER.rawValue
            let isTimedOut = abs(data.createdAt.toUTCDate().timeIntervalSinceNow) >= Call.timeoutInterval
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
    
    func minimizeIfThereIsAnActiveCall() {
        assert(Thread.isMainThread)
        guard activeCall != nil, !isInterfaceMinimized else {
            return
        }
        setInterfaceMinimized(true, animated: true)
    }
    
}

// MARK: - AudioSessionClient
extension CallService: AudioSessionClient {
    
    var priority: AudioSessionClientPriority {
        .voiceCall
    }
    
}

// MARK: - RTCAudioSessionDelegate
extension CallService: RTCAudioSessionDelegate {
    
    func audioSessionDidChangeRoute(_ session: RTCAudioSession, reason: AVAudioSession.RouteChangeReason, previousRoute: AVAudioSessionRouteDescription) {
        let currentPorts = session.currentRoute.outputs.map(\.portType)
        let newOutput: AudioOutput
        if currentPorts.contains(.builtInSpeaker) {
            newOutput = .builtInSpeaker
        } else if currentPorts.contains(.builtInReceiver) {
            newOutput = .builtInReceiver
        } else {
            newOutput = .other
        }
        Queue.main.autoSync {
            // RTCAudioSessionDelegate says it will call method "on a system notification thread"
            // But it comes on main thread sometimes
            guard self.audioOutput != newOutput else {
                return
            }
            self.audioOutput = newOutput
            NotificationCenter.default.post(name: Self.audioOutputDidChangeNotification, object: self)
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
        AccountAPI.updateSession(voipToken: .token(token))
        Logger.call.info(category: "CallService", message: "PushKit registered")
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        guard type == .voIP else {
            completion()
            return
        }
        beginBackgroundTaskIfNeeded()
        guard
            LoginManager.shared.isLoggedIn,
            !AppGroupUserDefaults.User.needsUpgradeInMainApp,
            adapter is CallKitAdapter,
            let userId = payload.dictionaryPayload["user_id"] as? String,
            let name = payload.dictionaryPayload["name"] as? String,
            let messageId = payload.dictionaryPayload["message_id"] as? String,
            !MessageDAO.shared.isExist(messageId: messageId)
        else {
            callKitAdapter.reportImmediateFailureCall()
            completion()
            endBackgroundTaskIfNeeded()
            return
        }
        
        if !name.isEmpty, let conversationId = payload.dictionaryPayload["conversation_id"] as? String, let conversation = ConversationDAO.shared.getConversation(conversationId: conversationId) {
            if let call = groupCall(with: conversationId) {
                // PushKit notifications may deliver AFTER the invitation was delivered with WebSocket
                // Report that call again to exonerate from PushKit abusing
                adapter.reportNewIncomingCall(call) { _ in }
            } else {
                let inviters: [UserItem]
                if let inviter = UserDAO.shared.getUser(userId: userId) {
                    inviters = [inviter]
                } else {
                    inviters = []
                }
                let call = GroupCall(conversation: conversation,
                                     isOutgoing: false,
                                     inviters: inviters,
                                     invitees: [])
                adapter.reportNewIncomingCall(call) { error in
                    if let error = error {
                        let reason = Call.EndedReason(error: error)
                        call.end(reason: reason, by: .local)
                        Logger.call.error(category: "CallService", message: "Incoming group call is blocked by adapter: \(error)")
                    } else {
                        Queue.main.autoSync {
                            self.groupCallUUIDs[conversation.conversationId] = call.uuid
                            self.calls[call.uuid] = call
                        }
                    }
                    completion()
                }
                MixinService.isStopProcessMessages = false
                WebSocketService.shared.connectIfNeeded()
                Logger.call.info(category: "CallService", message: "Report incoming group call from PushKit notification. UUID: \(call.uuidString)")
            }
        } else if name.isEmpty, let username = payload.dictionaryPayload["full_name"] as? String, let uuid = UUID(uuidString: messageId) {
            if let call = call(with: uuid) as? PeerCall {
                // PushKit notifications may deliver AFTER the offer was delivered with WebSocket
                // Report that call again to exonerate from PushKit abusing
                adapter.reportNewIncomingCall(call) { _ in }
            } else {
                let call = IncomingPeerCall(uuid: uuid,
                                            remoteUserId: userId,
                                            remoteUsername: username)
                adapter.reportNewIncomingCall(call) { error in
                    if let error = error {
                        let reason = Call.EndedReason(error: error)
                        call.end(reason: reason, by: .local)
                        Logger.call.error(category: "CallService", message: "Incoming peer call is blocked by adapter: \(error)")
                    } else {
                        Queue.main.autoSync {
                            self.calls[call.uuid] = call
                        }
                    }
                    completion()
                }
                MixinService.isStopProcessMessages = false
                WebSocketService.shared.connectIfNeeded()
                Logger.call.info(category: "CallService", message: "New incoming peer call from: \(username), uuid: \(call.uuidString)")
            }
        } else {
            Logger.call.info(category: "CallService", message: "report failed incoming call from PushKit notification")
            callKitAdapter.reportImmediateFailureCall()
            completion()
            endBackgroundTaskIfNeeded()
        }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP, registry.pushToken(for: .voIP) == nil else {
            return
        }
        AccountAPI.updateSession(voipToken: .remove)
        Logger.call.info(category: "CallService", message: "PushKit invalidated")
    }
    
}

// MARK: - CallMessageCoordinator
extension CallService: CallMessageCoordinator {
    
    func shouldSendRtcBlazeMessage(with category: MessageCategory) -> Bool {
        if [.WEBRTC_AUDIO_OFFER, .WEBRTC_AUDIO_ANSWER, .WEBRTC_ICE_CANDIDATE].contains(category) {
            return Queue.main.autoSync {
                self.hasCall
            }
        } else {
            return true
        }
    }
    
    func handleIncomingBlazeMessageData(_ data: BlazeMessageData) {
        guard let category = MessageCategory(rawValue: data.category) else {
            Logger.call.error(category: "CallService", message: "Invalid message category: \(data.category)")
            return
        }
        blazeProcessingQueue.async {
            let isListPendingMessage = data.source == BlazeMessageAction.listPendingMessages.rawValue
            let isTimedOut = -data.createdAt.toUTCDate().timeIntervalSinceNow >= Call.timeoutInterval
            
            switch category {
            case .WEBRTC_AUDIO_OFFER:
                guard let uuid = UUID(uuidString: data.messageId) else {
                    Logger.call.error(category: "CallService", message: "Offer with invalid UUID: \(data.messageId)")
                    return
                }
                let isCallRinging: Bool = DispatchQueue.main.sync {
                    self.handledUUIDs.insert(uuid)
                    return self.call(with: uuid) != nil
                }
                if isListPendingMessage && !isCallRinging {
                    if isTimedOut {
                        Logger.call.info(category: "CallService", message: "[\(data.messageId)] Offer from LIST_PENDING is timed out")
                        let cancel = Message.createWebRTCMessage(data: data, category: .WEBRTC_AUDIO_CANCEL, status: .DELIVERED)
                        MessageDAO.shared.insertMessage(message: cancel, messageSource: data.source)
                    } else {
                        let item = DispatchWorkItem {
                            Logger.call.info(category: "CallService", message: "[\(data.messageId)] Wakes from listPendingWorkItems")
                            self.listPendingWorkItems.removeValue(forKey: uuid)
                            self.handleOffer(data: data, uuid: uuid)
                            if let candidates = self.listPendingCandidates.removeValue(forKey: uuid) {
                                Logger.call.info(category: "CallService", message: "[\(data.messageId)] \(candidates.count) candidates wakes from listPendingCandidates")
                                for candidate in candidates {
                                    self.handleCandidate(callUUID: uuid, data: candidate)
                                }
                            } else {
                                Logger.call.info(category: "CallService", message: "[\(data.messageId)] No candidates wakes from listPendingCandidates")
                            }
                        }
                        self.listPendingWorkItems[uuid] = item
                        self.blazeProcessingQueue.asyncAfter(deadline: .now() + listPendingMessageDelay, execute: item)
                        Logger.call.info(category: "CallService", message: "[\(data.messageId)] Outdated offer from LIST_PENDING is saved")
                    }
                } else {
                    self.handleOffer(data: data, uuid: uuid)
                }
            case .WEBRTC_AUDIO_ANSWER:
                self.handleAnswer(data: data)
            case .WEBRTC_AUDIO_CANCEL, .WEBRTC_AUDIO_DECLINE, .WEBRTC_AUDIO_BUSY, .WEBRTC_AUDIO_FAILED, .WEBRTC_AUDIO_END:
                guard let callUUID = UUID(uuidString: data.quoteMessageId) else {
                    Logger.call.error(category: "CallService", message: "End with invalid UUID: \(data.messageId)")
                    return
                }
                if let item = self.listPendingWorkItems.removeValue(forKey: callUUID) {
                    item.cancel()
                    self.listPendingCandidates.removeValue(forKey: callUUID)
                    let cancel = Message.createWebRTCMessage(messageId: data.quoteMessageId,
                                                             conversationId: data.conversationId,
                                                             userId: data.userId,
                                                             category: category,
                                                             status: .DELIVERED)
                    MessageDAO.shared.insertMessage(message: cancel, messageSource: data.source)
                    Logger.call.info(category: "CallService", message: "[\(data.quoteMessageId)] Removed from listPendingWorkItems due to: \(category)")
                } else {
                    self.handlePeerCallEnd(uuid: callUUID, category: category, data: data)
                }
            case .WEBRTC_ICE_CANDIDATE:
                guard let callUUID = UUID(uuidString: data.quoteMessageId) else {
                    Logger.call.error(category: "CallService", message: "Candidate with invalid UUID: \(data.messageId)")
                    return
                }
                if self.listPendingWorkItems[callUUID] != nil {
                    var candidates = self.listPendingCandidates[callUUID] ?? []
                    candidates.append(data)
                    self.listPendingCandidates[callUUID] = candidates
                    Logger.call.info(category: "CallService", message: "[\(data.quoteMessageId)] Candidate is saved")
                } else {
                    self.handleCandidate(callUUID: callUUID, data: data)
                }
            case .KRAKEN_PUBLISH:
                self.handlePublish(data: data)
            case .KRAKEN_INVITE:
                if isListPendingMessage && isTimedOut {
                    let invitation = Message.createKrakenMessage(conversationId: data.conversationId,
                                                                 userId: data.userId,
                                                                 category: .KRAKEN_INVITE,
                                                                 createdAt: data.createdAt)
                    MessageDAO.shared.insertMessage(message: invitation, messageSource: "CallService")
                    Logger.call.info(category: "CallService", message: "[\(data.conversationId)] Outdated invitation is saved to db")
                } else {
                    // TODO: Invitations with LIST_PENDING could be handled more precisely
                    // For example, A invites me, B invites me, then A cancelled his invitation and invites me again
                    // Since cancel message is only associated with conversation_id, it needs some ref counting
                    // mechanism to determine whether this invitation should be presented or not
                    self.handleInvitation(data: data)
                }
            case .KRAKEN_END:
                self.handleKrakenEnd(data: data)
            case .KRAKEN_CANCEL:
                self.handleKrakenCancel(data: data)
            case .KRAKEN_DECLINE:
                self.handleKrakenDecline(data: data)
            default:
                Logger.call.error(category: "CallService", message: "Unhandled category: \(category)")
            }
        }
    }
    
}

// MARK: - UI Interface
extension CallService {
    
    func alert(error: Error) {
        let content: String
        if let error = error as? CallError {
            content = error.alertContent
        } else {
            content = R.string.localizable.chat_message_call_failed()
        }
        Queue.main.autoAsync {
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
    
    func showJoinGroupCallConfirmation(conversation: ConversationItem, memberIds ids: [String]) {
        let controller = GroupCallConfirmationViewController(conversation: conversation, service: self)
        controller.loadMembers(with: ids)
        addViewControllerAsContainersChildIfNeeded(controller)
        UIView.performWithoutAnimation(controller.view.layoutIfNeeded)
        controller.showContentViewIfNeeded(animated: true)
    }
    
    func setInterfaceMinimized(_ minimized: Bool, animated: Bool, completion: (() -> Void)? = nil) {
        assert(Thread.isMainThread)
        guard self.isInterfaceMinimized != minimized else {
            return
        }
        self.isInterfaceMinimized = minimized
        guard let min = UIApplication.homeContainerViewController?.minimizedCallViewController else {
            return
        }
        guard let max = self.viewController else {
            return
        }
        let duration: TimeInterval = 0.3
        let updateViews: () -> Void
        let animationCompletion: (Bool) -> Void
        if minimized {
            min.call = activeCall
            min.setViewHidden(true)
            updateViews = {
                max.hideContentView(completion: nil)
                min.setViewHidden(false)
            }
            animationCompletion = { (_) in
                if self.isInterfaceMinimized {
                    self.removeViewControllerAsContainersChildIfNeeded(max)
                }
                completion?()
            }
        } else {
            addViewControllerAsContainersChildIfNeeded(max)
            updateViews = {
                min.setViewHidden(true)
                max.showContentViewIfNeeded(animated: true)
            }
            animationCompletion = { (_) in
                min.call = nil
                completion?()
            }
        }
        if animated {
            UIView.animate(withDuration: duration,
                           animations: updateViews,
                           completion: animationCompletion)
        } else {
            UIView.performWithoutAnimation {
                updateViews()
                animationCompletion(true)
            }
        }
        Logger.call.info(category: "CallService", message: "Interface minimized: \(minimized)")
    }
    
    func showCallingInterface(call: Call, animated: Bool) {
        let viewController: CallViewController
        if let controller = self.viewController {
            viewController = controller
        } else {
            viewController = CallViewController(service: self)
            viewController.loadViewIfNeeded()
            self.viewController = viewController
        }
        addViewControllerAsContainersChildIfNeeded(viewController)
        UIView.performWithoutAnimation {
            viewController.reload(call: call)
            viewController.view.layoutIfNeeded()
        }
        viewController.showContentViewIfNeeded(animated: animated)
        isInterfaceMinimized = false
    }
    
    func dismissCallingInterface() {
        var needsLockScreen: Bool {
            !ScreenLockManager.shared.isLastAuthenticationStillValid && ScreenLockManager.shared.needsBiometricAuthentication
        }
        if needsLockScreen {
            ScreenLockManager.shared.showUnlockScreenView()
        }
        viewController?.disableConnectionDurationTimer()
        viewController?.hideContentView(completion: {
            guard self.activeCall == nil else {
                return
            }
            if let viewController = self.viewController {
                self.removeViewControllerAsContainersChildIfNeeded(viewController)
                self.viewController = nil
            }
            if needsLockScreen {
                ScreenLockManager.shared.showUnlockScreenView()
            }
        })
        if let mini = UIApplication.homeContainerViewController?.minimizedCallViewControllerIfLoaded {
            mini.setViewHidden(true)
            mini.updateViewSize()
            mini.panningController.placeViewNextToLastOverlayOrTopRight()
            Logger.call.info(category: "CallService", message: "Minimized call view dismissed")
        }
    }
    
    func addViewControllerAsContainersChildIfNeeded(_ viewController: CallViewController) {
        guard let container = UIApplication.homeContainerViewController else {
            return
        }
        guard viewController.parent == nil else {
            return
        }
        container.addChild(viewController)
        container.view.addSubview(viewController.view)
        viewController.view.snp.makeEdgesEqualToSuperview()
        viewController.didMove(toParent: container)
    }
    
    func removeViewControllerAsContainersChildIfNeeded(_ viewController: CallViewController) {
        guard viewController.parent != nil else {
            return
        }
        viewController.willMove(toParent: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
    }
    
}

// MARK: - Calling Interface
extension CallService {
    
    func makePeerCall(with remoteUser: UserItem) {
        assert(Thread.isMainThread)
        let call = OutgoingPeerCall(uuid: UUID(),
                                    remoteUser: remoteUser)
        makeCall(call)
    }
    
    func makeGroupCall(conversation: ConversationItem, invitees: [UserItem]) {
        assert(Thread.isMainThread)
        let call = GroupCall(conversation: conversation,
                             isOutgoing: true,
                             inviters: [],
                             invitees: invitees)
        makeCall(call)
    }
    
    func requestAnswerCall(with uuid: UUID) {
        assert(Thread.isMainThread)
        guard let call = call(with: uuid) else {
            dismissCallingInterface()
            return
        }
        adapter.requestAnswerCall(call) { error in
            guard let error = error else {
                return
            }
            Queue.main.autoSync(execute: self.dismissCallingInterface)
            Logger.call.error(category: "CallService", message: "Request answer call failed: \(error)")
        }
    }
    
    /// completion is called on main queue with true on success, false on failure
    func requestSetMute(with uuid: UUID, muted: Bool, completion: @escaping Call.Completion) {
        assert(Thread.isMainThread)
        guard let call = call(with: uuid) else {
            completion(CallError.missingCall(uuid: uuid))
            return
        }
        adapter.requestSetMute(call, muted: muted) { error in
            Queue.main.autoSync {
                completion(error)
            }
        }
    }
    
    func requestEndCall(with uuid: UUID) {
        assert(Thread.isMainThread)
        guard let call = call(with: uuid) else {
            dismissCallingInterface()
            return
        }
        Logger.call.info(category: "CallService", message: "Request end call: \(call.uuidString)")
        adapter.requestEndCall(call) { error in
            guard let error = error else {
                return
            }
            Queue.main.autoSync(execute: self.dismissCallingInterface)
            Logger.call.error(category: "CallService", message: "Request end call failed: \(error)")
        }
    }
    
    func setAudioOutput(_ output: AudioOutput) {
        RTCDispatcher.dispatchAsync(on: .typeAudioSession) {
            let session = RTCAudioSession.sharedInstance()
            guard session.isActive else {
                return
            }
            session.lockForConfiguration()
            defer {
                session.unlockForConfiguration()
            }
            do {
                switch output {
                case .builtInReceiver, .other:
                    try session.overrideOutputAudioPort(.none)
                case .builtInSpeaker:
                    try session.overrideOutputAudioPort(.speaker)
                }
                DispatchQueue.main.sync {
                    self.audioOutput = output
                    NotificationCenter.default.post(name: Self.audioOutputDidChangeNotification, object: self)
                }
            } catch {
                Logger.call.error(category: "CallService", message: "RTCAudioSession failed to update config: \(error)")
            }
        }
    }
    
}

// MARK: - CallAdapter Callback
extension CallService {
    
    func performStartCall(uuid: UUID, completion: @escaping Call.Completion) {
        assert(Thread.isMainThread)
        Logger.call.info(category: "CallService", message: "Perform start call: \(uuid)")
        guard let call = call(with: uuid) else {
            completion(CallError.missingCall(uuid: uuid))
            Logger.call.error(category: "CallService", message: "Missing call with: \(uuid) in performStartCall")
            return
        }
        if let call = call as? OutgoingPeerCall {
            call.sendOffer(completion: completion)
            showCallingInterface(call: call, animated: true)
        } else if let call = call as? GroupCall {
            self.groupCallUUIDs[call.conversationId] = uuid
            call.connect(isRestarting: false, completion: completion)
            showCallingInterface(call: call, animated: true)
        } else {
            completion(CallError.inconsistentCallStarted)
            Logger.call.error(category: "CallService", message: "Call cannot be started: \(call)")
        }
    }
    
    func performAnswerCall(uuid: UUID, completion: @escaping Call.Completion) {
        assert(Thread.isMainThread)
        Logger.call.info(category: "CallService", message: "Perform answer call: \(uuid)")
        guard let call = calls[uuid] else {
            completion(CallError.missingCall(uuid: uuid))
            Logger.call.error(category: "CallService", message: "Missing call with: \(uuid) in performAnswerCall")
            return
        }
        calls.removeValue(forKey: uuid)
        activeCall = call
        if let call = call as? IncomingPeerCall {
            call.requestAnswer(completion: completion)
            showCallingInterface(call: call, animated: true)
        } else if let call = call as? GroupCall {
            call.connect(isRestarting: false, completion: completion)
            showCallingInterface(call: call, animated: true)
        } else {
            completion(CallError.inconsistentCallAnswered)
            Logger.call.error(category: "CallService", message: "Call cannot be answered: \(call)")
        }
    }
    
    func performEndCall(uuid: UUID, completion: @escaping Call.Completion) {
        assert(Thread.isMainThread)
        Logger.call.info(category: "CallService", message: "Perform end call: \(uuid)")
        guard let call = call(with: uuid) else {
            completion(CallError.missingCall(uuid: uuid))
            Logger.call.error(category: "CallService", message: "Missing call with: \(uuid) in performEndCall")
            return
        }
        let reason: Call.EndedReason
        switch call.state {
        case .incoming:
            reason = .declined
        case .outgoing:
            reason = .cancelled
        default:
            reason = .ended
        }
        call.end(reason: reason, by: .local) {
            completion(nil)
        }
    }
    
    /// Returns nil on success, error on failure
    func performSetMute(uuid: UUID, muted: Bool) -> Error? {
        assert(Thread.isMainThread)
        if let call = call(with: uuid) {
            call.isMuted = muted
            return nil
        } else {
            return CallError.missingCall(uuid: uuid)
        }
    }
    
    func audioSessionDidActivated(_ audioSession: AVAudioSession) {
        assert(Thread.isMainThread)
        if let call = activeCall as? PeerCall, call.state == .outgoing {
            ringtonePlayer.play(ringtone: .outgoing)
        }
    }
    
}

// MARK: - Call Workers
extension CallService {
    
    private func makeCall(_ call: Call) {
        assert(Thread.isMainThread)
        guard WebSocketService.shared.isConnected else {
            alert(error: CallError.networkFailure)
            return
        }
        guard !hasCall else {
            alert(error: CallError.busy)
            return
        }
        requestRecordPermission {
            self.reloadCallAdapter()
            Logger.call.info(category: "CallService", message: "Call started with UUID: \(call.uuid)")
            if let confirmation = UIApplication.homeContainerViewController?.children.compactMap({ $0 as? GroupCallConfirmationViewController }).first {
                self.removeViewControllerAsContainersChildIfNeeded(confirmation)
                self.showCallingInterface(call: call, animated: false)
            }
            self.blazeProcessingQueue.async {
                try? AudioSession.shared.activate(client: self)
                DispatchQueue.main.async {
                    // The completion block passed to CallKit may get called before or after the CXStartCallAction
                    // is requested to perform by CXProvider. To guarantee the call exists when it trys to start
                    // with a UUID, we put that call into pending list before requesting the adapter to start it.
                    self.calls[call.uuid] = call
                    self.adapter.requestStartCall(call) { error in
                        Queue.main.autoSync {
                            self.calls[call.uuid] = nil
                            if let error = error {
                                self.alert(error: error)
                                Logger.call.warn(category: "CallService", message: "Adapter reports error on start call: \(error)")
                            } else {
                                self.activeCall = call
                            }
                        }
                    }
                }
            }
        }
    }
    
}

// MARK: - Call Update Handlers
extension CallService {
    
    @objc private func callStateDidChange(_ notification: Notification) {
        guard let call = notification.object as? Call else {
            return
        }
        guard let oldState = notification.userInfo?[Call.UserInfoKey.oldState] as? Call.State else {
            return
        }
        switch call.state {
        case .incoming, .outgoing:
            break
        case .connecting:
            ringtonePlayer.stop()
            if call is OutgoingPeerCall {
                adapter.reportOutgoingCallStartedConnecting(call)
            }
        case .connected:
            let justConnected = oldState == .connecting
            if justConnected {
                Vibrator.vibrateOnce()
            }
            if call is OutgoingPeerCall {
                adapter.reportOutgoingCallConnected(call)
            }
        case .restarting:
            break
        case .disconnecting:
            ringtonePlayer.stop()
        }
    }
    
    @objc private func callDidEnd(_ notification: Notification) {
        guard
            let call = notification.object as? Call,
            let reason = notification.userInfo?[Call.UserInfoKey.endedReason] as? Call.EndedReason,
            let side = notification.userInfo?[Call.UserInfoKey.endedSide] as? Call.EndedSide
        else {
            return
        }
        if activeCall == call {
            activeCall = nil
        }
        calls.removeValue(forKey: call.uuid)
        adapter.reportCall(call, endedByReason: reason, side: side)
        if !hasCall {
            dismissCallingInterface()
            isInterfaceMinimized = false
            reloadCallAdapter()
            blazeProcessingQueue.async {
                try? AudioSession.shared.deactivate(client: self, notifyOthersOnDeactivation: false)
            }
            if UIApplication.shared.applicationState == .background {
                Logger.call.info(category: "CallService", message: "Scheduled bg task ending")
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    // This could be done better with per-message notification about delivery status
                    // Currently there's no such mechanism, leave it with time-based delay
                    guard !self.hasCall else {
                        return
                    }
                    self.endBackgroundTaskIfNeeded()
                }
            } else {
                endBackgroundTaskIfNeeded()
            }
        }
    }
    
    @objc private func callDidUpdateLocalizedName(_ notification: Notification) {
        guard let call = notification.object as? Call else {
            return
        }
        adapter.reportCall(call, callerNameUpdatedWith: call.localizedName)
    }
    
}

// MARK: - Peer Call Handlers
extension CallService {
    
    private func handleOffer(data: BlazeMessageData, uuid: UUID) {
        guard let user = UserDAO.shared.getUser(userId: data.userId) else {
            Logger.call.error(category: "CallService", message: "Offer with inexisted user id: \(data.userId)")
            return
        }
        guard let sdpString = data.data.base64Decoded(), let sdp = RTCSessionDescription(jsonString: sdpString) else {
            Logger.call.error(category: "CallService", message: "Offer with invalid content: \(data.data)")
            return
        }
        if data.quoteMessageId.isEmpty {
            let (call, reportNewIncomingCall) = DispatchQueue.main.sync { () -> (IncomingPeerCall, Bool) in
                if let call = self.call(with: uuid) as? IncomingPeerCall {
                    call.remoteUser = user
                    return (call, false)
                } else {
                    let call = IncomingPeerCall(uuid: uuid, remoteUser: user)
                    self.calls[uuid] = call
                    return (call, true)
                }
            }
            Logger.call.info(category: "CallService", message: "New incoming peer call from: \(user.fullName), uuid: \(call.uuidString)")
            try? AudioSession.shared.activate(client: self)
            call.takeRemoteSDP(sdp) { error in
                if let error = error {
                    call.end(reason: .failed, by: .local)
                    Logger.call.error(category: "CallService", message: "Failed to take remote SDP from offer: \(error)")
                } else {
                    DispatchQueue.main.async {
                        guard reportNewIncomingCall else {
                            return
                        }
                        self.adapter.reportNewIncomingCall(call) { error in
                            guard let error = error else {
                                return
                            }
                            let reason = Call.EndedReason(error: error)
                            call.end(reason: reason, by: .local)
                            Logger.call.info(category: "CallService", message: "Incoming call is blocked by adapter: \(error)")
                        }
                    }
                }
            }
        } else {
            DispatchQueue.main.sync {
                guard let uuid = UUID(uuidString: data.quoteMessageId) else {
                    Logger.call.error(category: "CallService", message: "Restart offer with invalid UUID: \(data.quoteMessageId)")
                    return
                }
                guard let call = self.activeCall as? IncomingPeerCall, call.uuid == uuid else {
                    Logger.call.info(category: "CallService", message: "No corresponding call with: \(data.quoteMessageId), drop the restart offer")
                    return
                }
                Logger.call.info(category: "CallService", message: "Got restart offer for: \(call.uuidString)")
                call.takeRemoteSDP(sdp) { error in
                    guard let error = error else {
                        return
                    }
                    Logger.call.error(category: "CallService", message: "Failed to restart call: \(call.uuidString), reason: \(error)")
                    call.end(reason: .failed, by: .local)
                }
            }
        }
    }
    
    private func handleAnswer(data: BlazeMessageData) {
        guard let uuid = UUID(uuidString: data.quoteMessageId) else {
            Logger.call.error(category: "CallService", message: "Answer with invalid UUID: \(data.messageId)")
            return
        }
        guard let sdpString = data.data.base64Decoded(), let sdp = RTCSessionDescription(jsonString: sdpString) else {
            Logger.call.error(category: "CallService", message: "Answer with invalid content: \(data.data)")
            return
        }
        DispatchQueue.main.async {
            guard let call = self.call(with: uuid) as? OutgoingPeerCall else {
                Logger.call.info(category: "CallService", message: "Got answer without corresponding call: \(data.quoteMessageId)")
                return
            }
            call.takeRemoteAnswer(sdp: sdp) { error in
                guard let error = error else {
                    return
                }
                call.end(reason: .failed, by: .local)
                Logger.call.error(category: "CallService", message: "Failed to take remote SDP from answer: \(error)")
            }
        }
    }
    
    private func handlePeerCallEnd(uuid: UUID, category: MessageCategory, data: BlazeMessageData) {
        let reason: Call.EndedReason
        switch category {
        case .WEBRTC_AUDIO_CANCEL:
            reason = .cancelled
        case .WEBRTC_AUDIO_DECLINE:
            reason = .declined
        case .WEBRTC_AUDIO_BUSY:
            reason = .busy
        case .WEBRTC_AUDIO_FAILED:
            reason = .failed
        case.WEBRTC_AUDIO_END:
            reason = .ended
        default:
            Logger.call.info(category: "CallService", message: "Invalid end call category: \(data.category)")
            return
        }
        DispatchQueue.main.async {
            guard let call = self.call(with: uuid) as? PeerCall else {
                Logger.call.info(category: "CallService", message: "Got \(data.category) without corresponding call: \(data.quoteMessageId)")
                return
            }
            call.end(reason: reason, by: .remote)
        }
    }
    
    private func handleCandidate(callUUID: UUID, data: BlazeMessageData) {
        guard let candidatesString = data.data.base64Decoded() else {
            Logger.call.error(category: "CallService", message: "Candidate with invalid content: \(data.data)")
            return
        }
        let newCandidates = [RTCIceCandidate](jsonString: candidatesString)
        guard !newCandidates.isEmpty else {
            Logger.call.error(category: "CallService", message: "Got empty candidates for: \(callUUID)")
            return
        }
        DispatchQueue.main.async {
            guard let call = self.call(with: callUUID) as? PeerCall else {
                Logger.call.info(category: "CallService", message: "Got candidate without corresponding call: \(data.quoteMessageId)")
                return
            }
            call.addRemoteCandidates(newCandidates)
        }
    }
    
}

// MARK: - Group Call Handlers
extension CallService {
    
    private func handlePublish(data: BlazeMessageData) {
        Logger.call.info(category: "CallService", message: "Got publish from: \(data.userId), conversation: \(data.conversationId)")
        membersManager.addMember(with: data.userId, toConversationWith: data.conversationId)
        DispatchQueue.main.sync {
            guard let call = self.groupCall(with: data.conversationId) else {
                return
            }
            call.subscribe(to: .user(data.userId))
        }
    }
    
    private func handleInvitation(data: BlazeMessageData) {
        let reportNewIncomingCall: Bool = DispatchQueue.main.sync {
            if let call = self.groupCall(with: data.conversationId) {
                if call.state == .incoming {
                    call.appendInviter(with: data.userId)
                }
                return false
            } else {
                return true
            }
        }
        guard reportNewIncomingCall else {
            return
        }
        guard let conversation = ConversationDAO.shared.getConversation(conversationId: data.conversationId) else {
            Logger.call.error(category: "CallService", message: "No conversation: \(data.conversationId)")
            return
        }
        let inviters: [UserItem]
        if let user = UserDAO.shared.getUser(userId: data.userId) {
            inviters = [user]
        } else {
            inviters = []
        }
        let call = GroupCall(conversation: conversation,
                             isOutgoing: false,
                             inviters: inviters,
                             invitees: [])
        try? AudioSession.shared.activate(client: self)
        DispatchQueue.main.async {
            self.groupCallUUIDs[data.conversationId] = call.uuid
            self.calls[call.uuid] = call
            self.adapter.reportNewIncomingCall(call) { error in
                if let error = error {
                    let reason = Call.EndedReason(error: error)
                    call.end(reason: reason, by: .local)
                    Logger.call.error(category: "CallService", message: "Incoming call is blocked by adapter: \(error)")
                } else {
                    call.scheduleUnansweredTimer()
                    DispatchQueue.global().async {
                        let invitation = Message.createKrakenMessage(conversationId: data.conversationId,
                                                                     userId: data.userId,
                                                                     category: .KRAKEN_INVITE,
                                                                     status: MessageStatus.READ.rawValue,
                                                                     createdAt: data.createdAt)
                        MessageDAO.shared.insertMessage(message: invitation, messageSource: "CallService")
                    }
                }
            }
        }
        
    }
    
    private func handleKrakenEnd(data: BlazeMessageData) {
        Logger.call.info(category: "CallService", message: "KRAKEN_END from \(data.userId)")
        membersManager.removeMember(with: data.userId, fromConversationWith: data.conversationId)
        DispatchQueue.main.async {
            guard let call = self.groupCall(with: data.conversationId) else {
                return
            }
            call.reportEnd(fromUserWith: data.userId)
        }
    }
    
    private func handleKrakenCancel(data: BlazeMessageData) {
        Logger.call.info(category: "CallService", message: "KRAKEN_CANCEL from \(data.userId)")
        DispatchQueue.main.async {
            guard let call = self.groupCall(with: data.conversationId) else {
                return
            }
            call.removeInviter(with: data.userId, createdAt: data.createdAt)
        }
    }
    
    private func handleKrakenDecline(data: BlazeMessageData) {
        Logger.call.info(category: "CallService", message: "KRAKEN_DECLINE from \(data.userId)")
        membersManager.removeMember(with: data.userId, fromConversationWith: data.conversationId)
        DispatchQueue.main.async {
            guard let call = self.groupCall(with: data.conversationId) else {
                return
            }
            call.reportDecline(fromUserWith: data.userId, createdAt: data.createdAt)
        }
    }
    
}

// MARK: - Private Works
extension CallService {
    
    private func call(with uuid: UUID) -> Call? {
        assert(Thread.isMainThread)
        if let call = activeCall, call.uuid == uuid {
            return call
        } else {
            return calls[uuid]
        }
    }
    
    private func groupCall(with conversationId: String) -> GroupCall? {
        assert(Thread.isMainThread)
        guard let uuid = groupCallUUIDs[conversationId] else {
            return nil
        }
        if let call = call(with: uuid) as? GroupCall {
            return call
        } else {
            Logger.call.error(category: "CallService", message: "Inconsistent group call with cid: \(conversationId), uuid: \(uuid)")
            return nil
        }
    }
    
    private func requestRecordPermission(onGranted: @escaping () -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { isGranted in
            if isGranted {
                Queue.main.autoAsync(execute: onGranted)
            } else {
                self.alert(error: CallError.microphonePermissionDenied)
            }
        }
    }
    
    private func reloadCallAdapter() {
        assert(Thread.isMainThread)
        guard !hasCall else {
            return
        }
        let usesCallKit = !isCallKitForbidden && AVAudioSession.sharedInstance().recordPermission == .granted
        if usesCallKit {
            if adapter == nil || !(adapter is CallKitAdapter) {
                Logger.call.info(category: "CallService", message: "Using CallKitAdapter")
                adapter = callKitAdapter
                RTCAudioSession.sharedInstance().useManualAudio = true
            }
        } else {
            if adapter == nil || !(adapter is GeneralAdapter) {
                Logger.call.info(category: "CallService", message: "Using GeneralAdapter")
                adapter = GeneralAdapter(service: self)
                RTCAudioSession.sharedInstance().useManualAudio = false
            }
        }
    }
    
}

// MARK: - Background Task
extension CallService {
    
    private func beginBackgroundTaskIfNeeded() {
        assert(Thread.isMainThread)
        guard backgroundTaskIdentifier == .invalid else {
            return
        }
        let app = UIApplication.shared
        backgroundTaskIdentifier = app.beginBackgroundTask(withName: "CallService") {
            Logger.call.warn(category: "CallService", message: "Background task about to expire with: \(self.backgroundTaskIdentifier)")
            self.endBackgroundTaskIfNeeded()
        }
        Logger.call.info(category: "CallService", message: "Background task started with: \(backgroundTaskIdentifier)")
    }
    
    private func endBackgroundTaskIfNeeded() {
        assert(Thread.isMainThread)
        guard backgroundTaskIdentifier != .invalid else {
            return
        }
        if UIApplication.shared.applicationState == .background && !BackgroundMessagingService.shared.hasBackgroundTaskScheduled {
            MixinService.isStopProcessMessages = true
            WebSocketService.shared.disconnect()
            Logger.call.info(category: "CallService", message: "WS disconnected by bg task")
        }
        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        Logger.call.info(category: "CallService", message: "Background task ended with: \(backgroundTaskIdentifier)")
        backgroundTaskIdentifier = .invalid
    }
    
}
