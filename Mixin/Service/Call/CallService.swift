import Foundation
import PushKit
import WebRTC
import MixinServices

class CallService: NSObject {
    
    typealias PendingOffer = (call: Call, sdp: RTCSessionDescription)
    
    static let shared = CallService()
    static let mutenessDidChangeNotification = Notification.Name("one.mixin.messenger.call-service.muteness-did-change")
    
    static var isCallKitAvailable: Bool {
        let isMainlandChina = false
        return !isMainlandChina && AVAudioSession.sharedInstance().recordPermission == .granted
    }
    
    private(set) lazy var ringtonePlayer = RingtonePlayer()
    
    private(set) var activeCall: Call?
    
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
            guard rtcClient.iceConnectionState == .connected else {
                return
            }
            queue.async {
                let port: AVAudioSession.PortOverride = self.usesSpeaker ? .speaker : .none
                try? AVAudioSession.sharedInstance().overrideOutputAudioPort(port)
            }
        }
    }
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.call-manager")
    
    private lazy var pushRegistry = PKPushRegistry(queue: .main)
    private lazy var rtcClient = WebRTCClient()
    private lazy var vibrator = Vibrator()
    private lazy var nativeCallInterface = NativeCallInterface(manager: self)
    private lazy var mixinCallInterface = MixinCallInterface(manager: self)
    
    private var window: CallWindow?
    private var viewController: CallViewController?
    private var pendingOffers = [UUID: PendingOffer]()
    private var pendingCandidates = [UUID: [RTCIceCandidate]]()
    
    // UUID of the call coming from PushKit, that is already choosed to answer with CallKit,
    // but still waiting for the SDP description arrived through WebSocket
    private var pendingAnswerUuid: UUID?
    
    private weak var unansweredTimer: Timer?
    
    private var callInterface: CallInterface {
        Self.isCallKitAvailable ? nativeCallInterface : mixinCallInterface
    }
    
    override init() {
        super.init()
        rtcClient.delegate = self
    }
    
    func showCallingInterface(user: UserItem, style: CallViewController.Style) {
        
        func makeViewController() -> CallViewController {
            let viewController = CallViewController()
            viewController.service = self
            viewController.loadViewIfNeeded()
            self.viewController = viewController
            return viewController
        }
        
        let animated = self.window != nil
        
        let viewController = self.viewController ?? makeViewController()
        viewController.reload(user: user)
        
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
    
    func dismissCallingInterface() {
        AppDelegate.current.mainWindow.makeKeyAndVisible()
        viewController?.disableConnectionDurationTimer()
        viewController = nil
        window = nil
    }
    
    func registerForPushKitNotificationsIfAvailable() {
        guard Self.isCallKitAvailable else {
            return
        }
        pushRegistry.desiredPushTypes = [.voIP]
        pushRegistry.delegate = self
        if let token = pushRegistry.pushToken(for: .voIP)?.toHexString() {
            AccountAPI.shared.updateSession(voipToken: token)
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
        AppDelegate.current.cancelBackgroundTask()
        MixinService.isStopProcessMessages = false
        WebSocketService.shared.connectIfNeeded()
        nativeCallInterface.reportNewIncomingCall(uuid: uuid, userId: userId, username: username) { (error) in
            completion()
        }
    }
    
}

// MARK: - Interface
extension CallService {
    
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
    
    func requestStartCall(opponentUser: UserItem) {
        let uuid = UUID()
        callInterface.requestStartCall(uuid: uuid, handle: .userId(opponentUser.userId)) { (error) in
            if let error = error as? CallError {
                self.alert(error: error)
            } else if let error = error {
                reporter.report(error: error)
                showAutoHiddenHud(style: .error, text: R.string.localizable.chat_message_call_failed())
            }
        }
    }
    
    func requestEndCall() {
        guard let uuid = activeCall?.uuid ?? pendingOffers.first?.key else {
            return
        }
        callInterface.requestEndCall(uuid: uuid) { (error) in
            if let error = error {
                // Don't think we would get error here
                reporter.report(error: error)
                self.endCall(uuid: uuid)
            }
        }
    }
    
    func requestAnswerCall() {
        guard let uuid = pendingOffers.first?.key else {
            return
        }
        answerCall(uuid: uuid, completion: nil)
    }
    
    func requestSetMute(_ muted: Bool) {
        guard let uuid = activeCall?.uuid else {
            return
        }
        callInterface.requestSetMute(uuid: uuid, muted: muted) { (error) in
            if let error = error {
                reporter.report(error: error)
            }
        }
    }
    
    func alert(error: CallError) {
        let content = error.alertContent
        DispatchQueue.main.async {
            if case .microphonePermissionDenied = error {
                AppDelegate.current.mainWindow.rootViewController?.alertSettings(content)
            } else {
                AppDelegate.current.mainWindow.rootViewController?.alert(content)
            }
        }
    }
    
}

// MARK: - Callback
extension CallService {
    
    func startCall(uuid: UUID, handle: CallHandle, completion: ((Bool) -> Void)?) {
        AudioManager.shared.pause()
        queue.async {
            let user: UserItem? = {
                switch handle {
                case .userId(let userId):
                    return UserDAO.shared.getUser(userId: userId)
                case .phoneNumber(let number):
                    return UserDAO.shared.getUser(phoneNumber: number)
                }
            }()
            guard let opponentUser = user else {
                self.alert(error: .invalidHandle)
                completion?(false)
                return
            }
            guard WebSocketService.shared.isConnected else {
                self.alert(error: .networkFailure)
                completion?(false)
                return
            }
            DispatchQueue.main.sync {
                self.showCallingInterface(user: opponentUser, style: .outgoing)
            }
            let call = Call(uuid: uuid, opponentUser: opponentUser, isOutgoing: true)
            self.activeCall = call
            
            let timer = Timer(timeInterval: callTimeoutInterval,
                              target: self,
                              selector: #selector(self.unansweredTimeout),
                              userInfo: nil,
                              repeats: false)
            RunLoop.main.add(timer, forMode: .default)
            self.unansweredTimer = timer
            
            self.rtcClient.offer { (sdp, error) in
                guard let sdp = sdp else {
                    self.queue.async {
                        self.failCurrentCall(sendFailedMessageToRemote: false,
                                             error: .sdpConstruction(error))
                        completion?(false)
                    }
                    return
                }
                guard let content = sdp.jsonString else {
                    self.queue.async {
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
                completion?(true)
            }
        }
    }
    
    func answerCall(uuid: UUID, completion: ((Bool) -> Void)?) {
        queue.async {
            guard let (call, offer) = self.pendingOffers.removeValue(forKey: uuid) else {
                self.pendingAnswerUuid = uuid
                completion?(true)
                return
            }
            DispatchQueue.main.sync {
                self.showCallingInterface(user: call.opponentUser, style: .connecting)
            }
            self.activeCall = call
            for uuid in self.pendingOffers.keys {
                self.endCall(uuid: uuid)
            }
            self.ringtonePlayer.stop()
            self.rtcClient.set(remoteSdp: offer) { (error) in
                if let error = error {
                    self.queue.async {
                        self.failCurrentCall(sendFailedMessageToRemote: true,
                                             error: .setRemoteSdp(error))
                        completion?(false)
                    }
                } else {
                    self.rtcClient.answer(completion: { (answer, error) in
                        self.queue.async {
                            guard let answer = answer, let content = answer.jsonString else {
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
                            if let candidates = self.pendingCandidates.removeValue(forKey: uuid) {
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
            let msg = Message.createWebRTCMessage(conversationId: call.conversationId,
                                                  category: category,
                                                  status: .SENDING,
                                                  quoteMessageId: call.uuidString)
            SendMessageService.shared.sendWebRTCMessage(message: msg,
                                                        recipientId: call.opponentUser.userId)
            insertCallCompletedMessage(call: call,
                                       isUserInitiated: true,
                                       category: category)
        }
        
        queue.async {
            if let call = self.activeCall, call.uuid == uuid {
                self.unansweredTimer?.invalidate()
                DispatchQueue.main.sync {
                    self.viewController?.style = .disconnecting
                }
                self.ringtonePlayer.stop()
                self.rtcClient.close()
                let category: MessageCategory
                if call.connectedDate != nil {
                    category = .WEBRTC_AUDIO_END
                } else if call.isOutgoing {
                    category = .WEBRTC_AUDIO_CANCEL
                } else {
                    category = .WEBRTC_AUDIO_DECLINE
                }
                sendEndMessage(call: call, category: category)
                self.activeCall = nil
                self.isMuted = false
                self.usesSpeaker = false
                DispatchQueue.main.sync(execute: self.dismissCallingInterface)
            } else if let (call, _) = self.pendingOffers.removeValue(forKey: uuid) {
                sendEndMessage(call: call, category: .WEBRTC_AUDIO_DECLINE)
                if self.pendingOffers.isEmpty && self.activeCall == nil {
                    self.ringtonePlayer.stop()
                    DispatchQueue.main.sync(execute: self.dismissCallingInterface)
                }
            } else {
                DispatchQueue.main.sync(execute: self.dismissCallingInterface)
                self.usesSpeaker = false
                self.isMuted = false
            }
            self.pendingCandidates[uuid] = nil
        }
    }
    
    func clean() {
        rtcClient.close()
        activeCall = nil
        pendingOffers = [:]
        isMuted = false
        usesSpeaker = false
        ringtonePlayer.stop()
        unansweredTimer?.invalidate()
        performSynchronouslyOnMainThread {
            vibrator.stop()
            dismissCallingInterface()
        }
    }
    
}

extension CallService: CallMessageCoordinator {
    
    func shouldSendRtcBlazeMessage(with category: MessageCategory) -> Bool {
        let onlySendIfThereIsAnActiveCall = [.WEBRTC_AUDIO_OFFER, .WEBRTC_AUDIO_ANSWER, .WEBRTC_ICE_CANDIDATE].contains(category)
        return activeCall != nil || !onlySendIfThereIsAnActiveCall
    }
    
    func handleIncomingBlazeMessageData(_ data: BlazeMessageData) {
        queue.async {
            switch data.category {
            case MessageCategory.WEBRTC_AUDIO_OFFER.rawValue:
                self.handleOffer(data: data)
            case MessageCategory.WEBRTC_ICE_CANDIDATE.rawValue:
                self.handleIceCandidate(data: data)
            default:
                self.handleCallStatusChange(data: data)
            }
        }
    }
    
}

// MARK: - Blaze message data handlers
extension CallService {
    
    private func handleOffer(data: BlazeMessageData) {
        
        func declineOffer(data: BlazeMessageData, category: MessageCategory) {
            let offer = Message.createWebRTCMessage(data: data, category: category, status: .DELIVERED)
            MessageDAO.shared.insertMessage(message: offer, messageSource: "")
            let reply = Message.createWebRTCMessage(quote: data, category: category, status: .SENDING)
            SendMessageService.shared.sendWebRTCMessage(message: reply, recipientId: data.getSenderId())
            if let uuid = UUID(uuidString: data.messageId) {
                pendingOffers.removeValue(forKey: uuid)
                pendingCandidates.removeValue(forKey: uuid)
                if pendingAnswerUuid == uuid {
                    pendingAnswerUuid = nil
                }
            }
        }
        
        do {
            guard let uuid = UUID(uuidString: data.messageId) else {
                throw CallError.invalidUUID(uuid: data.messageId)
            }
            guard let sdpString = data.data.base64Decoded(), let sdp = RTCSessionDescription(jsonString: sdpString) else {
                throw CallError.invalidSdp(sdp: data.data)
            }
            guard let user = UserDAO.shared.getUser(userId: data.userId) else {
                throw CallError.missingUser(userId: data.userId)
            }
            AudioManager.shared.pause()
            let call = Call(uuid: uuid, opponentUser: user, isOutgoing: false)
            pendingOffers[uuid] = PendingOffer(call: call, sdp: sdp)
            
            if uuid == self.pendingAnswerUuid {
                self.pendingAnswerUuid = nil
                self.requestAnswerCall()
            } else {
                var reportingError: Error?
                let semaphore = DispatchSemaphore(value: 0)
                callInterface.reportNewIncomingCall(call) { (error) in
                    reportingError = error
                    semaphore.signal()
                }
                semaphore.wait()
                
                if let error = reportingError {
                    throw error
                }
            }
        } catch CallError.busy {
            declineOffer(data: data, category: .WEBRTC_AUDIO_BUSY)
        } catch CallError.microphonePermissionDenied {
            declineOffer(data: data, category: .WEBRTC_AUDIO_DECLINE)
            alert(error: .microphonePermissionDenied)
        } catch {
            declineOffer(data: data, category: .WEBRTC_AUDIO_FAILED)
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
        if let call = activeCall, uuid == call.uuid, call.isOutgoing, data.category == MessageCategory.WEBRTC_AUDIO_ANSWER.rawValue, let sdpString = data.data.base64Decoded(), let sdp = RTCSessionDescription(jsonString: sdpString) {
            unansweredTimer?.invalidate()
            callInterface.reportOutgoingCallStartedConnecting(uuid: uuid)
            ringtonePlayer.stop()
            DispatchQueue.main.sync {
                viewController?.style = .connecting
            }
            rtcClient.set(remoteSdp: sdp) { (error) in
                if let error = error {
                    self.queue.async {
                        self.failCurrentCall(sendFailedMessageToRemote: true,
                                             error: .setRemoteAnswer(error))
                        self.callInterface.reportCall(uuid: uuid,
                                                      endedByReason: .failed)
                    }
                }
            }
        } else if let category = MessageCategory(rawValue: data.category), MessageCategory.endCallCategories.contains(category) {
            
            func insertMessageAndReport(call: Call) {
                insertCallCompletedMessage(call: call, isUserInitiated: false, category: category)
                callInterface.reportCall(uuid: call.uuid, endedByReason: .remoteEnded)
            }
            
            if let call = activeCall, call.uuid == uuid {
                DispatchQueue.main.sync {
                    viewController?.style = .disconnecting
                }
                insertMessageAndReport(call: call)
                clean()
            } else if let call = pendingOffers[uuid]?.call {
                ringtonePlayer.stop()
                insertMessageAndReport(call: call)
                pendingOffers.removeValue(forKey: uuid)
            }
        }
    }
    
    private func insertCallCompletedMessage(call: Call, isUserInitiated: Bool, category: MessageCategory?) {
        let timeIntervalSinceNow = call.connectedDate?.timeIntervalSinceNow ?? 0
        let duration = abs(timeIntervalSinceNow * millisecondsPerSecond)
        let category = category ?? .WEBRTC_AUDIO_FAILED
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
    }
    
    func webRTCClientDidConnected(_ client: WebRTCClient) {
        queue.async {
            guard let call = self.activeCall else {
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
            DispatchQueue.main.sync {
                self.viewController?.style = .connected
            }
            
            // https://stackoverflow.com/questions/49170274/callkit-loudspeaker-bug-how-whatsapp-fixed-it
            let session = RTCAudioSession.sharedInstance()
            session.lockForConfiguration()
            do {
                try session.setCategory(AVAudioSession.Category.playAndRecord.rawValue, with: .allowBluetooth)
                try session.setMode(AVAudioSession.Mode.default.rawValue)
            } catch {
                reporter.report(error: error)
            }
            session.unlockForConfiguration()
        }
    }
    
    func webRTCClientDidFailed(_ client: WebRTCClient) {
        queue.async {
            self.failCurrentCall(sendFailedMessageToRemote: true, error: .clientFailure)
        }
    }
    
}

extension CallService {
    
    @objc private func unansweredTimeout() {
        guard let call = activeCall, call.isOutgoing, !call.hasReceivedRemoteAnswer else {
            return
        }
        dismissCallingInterface()
        rtcClient.close()
        isMuted = false
        queue.async {
            self.ringtonePlayer.stop()
            let msg = Message.createWebRTCMessage(conversationId: call.conversationId,
                                                  category: .WEBRTC_AUDIO_CANCEL,
                                                  status: .SENDING,
                                                  quoteMessageId: call.uuidString)
            SendMessageService.shared.sendWebRTCMessage(message: msg, recipientId: call.opponentUser.userId)
            self.insertCallCompletedMessage(call: call, isUserInitiated: false, category: .WEBRTC_AUDIO_CANCEL)
            self.activeCall = nil
            self.callInterface.reportCall(uuid: call.uuid, endedByReason: .unanswered)
        }
    }
    
    private func failCurrentCall(sendFailedMessageToRemote: Bool, error: CallError) {
        guard let call = activeCall else {
            return
        }
        if sendFailedMessageToRemote {
            let msg = Message.createWebRTCMessage(conversationId: call.conversationId,
                                                  category: .WEBRTC_AUDIO_FAILED,
                                                  status: .SENDING,
                                                  quoteMessageId: call.uuidString)
            SendMessageService.shared.sendMessage(message: msg,
                                                  ownerUser: call.opponentUser,
                                                  isGroupMessage: false)
        }
        let failedMessage = Message.createWebRTCMessage(messageId: call.uuidString,
                                                        conversationId: call.conversationId,
                                                        category: .WEBRTC_AUDIO_FAILED,
                                                        status: .DELIVERED)
        MessageDAO.shared.insertMessage(message: failedMessage, messageSource: "")
        clean()
        reporter.report(error: error)
    }
    
}
