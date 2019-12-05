import Foundation
import WebRTC
import CallKit
import UserNotifications

class CallManager {
    
    static let shared = CallManager()
    static let unansweredTimeoutInterval: TimeInterval = 60
    
    private let rtcClient = WebRTCClient()
    private let queue = DispatchQueue(label: "one.mixin.messenger.call-manager")
    private let vibrator = Vibrator()
    private let ringtonePlayer = try? AVAudioPlayer(contentsOf: Bundle.main.url(forResource: "call", withExtension: "caf")!)
    
    private(set) var call: Call?
    
    private(set) lazy var view: CallView = performSynchronouslyOnMainThread {
        let view = CallView(effect: UIBlurEffect(style: .dark))
        view.manager = self
        return view
    }
    
    private var unansweredTimer: Timer?
    private var pendingRemoteSdp: RTCSessionDescription?
    private var lineIsIdle: Bool {
        return call == nil && CallManager.callObserver.calls.isEmpty
    }
    
    var isMuted = false {
        didSet {
            guard rtcClient.iceConnectionState == .connected else {
                return
            }
            rtcClient.isMuted = isMuted
        }
    }
    
    var usesSpeaker = false {
        didSet {
            guard rtcClient.iceConnectionState == .connected else {
                return
            }
            queue.async {
                try? AVAudioSession.sharedInstance().overrideOutputAudioPort(self.portOverride)
            }
        }
    }
    
    init() {
        rtcClient.delegate = self
        ringtonePlayer?.numberOfLoops = -1
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(audioSessionRouteChange(_:)),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func checkPreconditionsAndCallIfPossible(opponentUser: UserItem) {
        guard WebSocketService.shared.isConnected && lineIsIdle else {
            alertNetworkFailureOrLineBusy()
            return
        }
        switch AVAudioSession.sharedInstance().recordPermission {
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { (granted) in
                if granted {
                    self.call(opponentUser: opponentUser)
                } else {
                    self.alertNoMicrophonePermission()
                }
            }
        case .denied:
            alertNoMicrophonePermission()
        case .granted:
            call(opponentUser: opponentUser)
        @unknown default:
            alertNoMicrophonePermission()
        }
    }
    
    func completeCurrentCall(isUserInitiated: Bool) {
        vibrator.stopVibrating()
        queue.async {
            guard let call = self.call else {
                DispatchQueue.main.sync {
                    self.view.style = .disconnecting
                    self.view.dismiss()
                }
                return
            }
            self.invalidateUnansweredTimeoutTimerAndSetNil()
            DispatchQueue.main.sync {
                self.view.style = .disconnecting
            }
            let category: MessageCategory
            if self.rtcClient.iceConnectionState == .connected {
                category = .WEBRTC_AUDIO_END
            } else if call.isOutgoing {
                category = .WEBRTC_AUDIO_CANCEL
            } else {
                category = .WEBRTC_AUDIO_DECLINE
            }
            self.ringtonePlayer?.stop()
            self.rtcClient.close()
            let msg = Message.createWebRTCMessage(conversationId: call.conversationId,
                                                  category: category,
                                                  status: .SENDING,
                                                  quoteMessageId: call.uuidString)
            SendMessageService.shared.sendWebRTCMessage(message: msg,
                                                        recipientId: call.opponentUser.userId)
            CallManager.insertCallCompletedMessage(call: call,
                                                   isUserInitiated: isUserInitiated,
                                                   category: category)
            DispatchQueue.main.sync {
                self.view.dismiss()
                self.isMuted = false
                self.usesSpeaker = false
            }
            self.call = nil
        }
    }
    
    func acceptCurrentCall() {
        view.style = .connecting
        vibrator.stopVibrating()
        queue.async {
            guard let call = self.call, let sdp = self.pendingRemoteSdp else {
                return
            }
            self.ringtonePlayer?.stop()
            self.usesSpeaker = false
            self.rtcClient.set(remoteSdp: sdp) { (error) in
                if let error = error {
                    self.queue.async {
                        self.failCurrentCall(sendFailedMesasgeToRemote: true,
                                             reportAction: "Set remote Sdp",
                                             description: error.localizedDescription)
                    }
                } else {
                    self.rtcClient.answer(completion: { (sdp, error) in
                        self.queue.async {
                            if let sdp = sdp, let content = sdp.jsonString {
                                let msg = Message.createWebRTCMessage(conversationId: call.conversationId,
                                                                      category: .WEBRTC_AUDIO_ANSWER,
                                                                      content: content,
                                                                      status: .SENDING,
                                                                      quoteMessageId: call.uuidString)
                                SendMessageService.shared.sendMessage(message: msg,
                                                                      ownerUser: call.opponentUser,
                                                                      isGroupMessage: false)
                            } else {
                                self.failCurrentCall(sendFailedMesasgeToRemote: true,
                                                     reportAction: "Answer construction",
                                                     description: error.debugDescription)
                            }
                        }
                    })
                }
            }
        }
    }
    
    func handleIncomingBlazeMessageData(_ data: BlazeMessageData) {
        queue.async {
            switch data.category {
            case MessageCategory.WEBRTC_AUDIO_OFFER.rawValue:
                do {
                    try self.checkPreconditionsAndHandleIncomingCallIfPossible(data: data)
                } catch CallError.busy {
                    CallManager.insertOfferAndSendWebRTCMessage(against: data, category: .WEBRTC_AUDIO_BUSY)
                } catch CallError.microphonePermissionDenied {
                    CallManager.insertOfferAndSendWebRTCMessage(against: data, category: .WEBRTC_AUDIO_DECLINE)
                    self.alertNoMicrophonePermission()
                } catch {
                    CallManager.insertOfferAndSendWebRTCMessage(against: data, category: .WEBRTC_AUDIO_FAILED)
                }
            case MessageCategory.WEBRTC_ICE_CANDIDATE.rawValue:
                self.handleIncomingIceCandidateIfNeeded(data: data)
            default:
                self.handleCallStatusChangeIfNeeded(data: data)
            }
        }
    }
    
}

extension CallManager {
    
    static let completeCallCategories: [MessageCategory] = [
        .WEBRTC_AUDIO_END,
        .WEBRTC_AUDIO_BUSY,
        .WEBRTC_AUDIO_CANCEL,
        .WEBRTC_AUDIO_FAILED,
        .WEBRTC_AUDIO_DECLINE
    ]
    
    private static let callObserver = CXCallObserver()
    
    static func insertCallCompletedMessage(call: Call, isUserInitiated: Bool, category: MessageCategory?) {
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
    
    private static func insertOfferAndSendWebRTCMessage(against data: BlazeMessageData, category: MessageCategory) {
        let messageToInsert = Message.createWebRTCMessage(data: data, category: category, status: .DELIVERED)
        MessageDAO.shared.insertMessage(message: messageToInsert, messageSource: "")
        let messageToSend = Message.createWebRTCMessage(quote: data, category: category, status: .SENDING)
        SendMessageService.shared.sendWebRTCMessage(message: messageToSend, recipientId: data.getSenderId())
    }
    
    private func checkPreconditionsAndHandleIncomingCallIfPossible(data: BlazeMessageData) throws {
        guard lineIsIdle else {
            throw CallError.busy
        }
        switch AVAudioSession.sharedInstance().recordPermission {
        case .undetermined:
            try handleIncomingCall(data: data, reportIncomingCallToInterface: true)
            AVAudioSession.sharedInstance().requestRecordPermission { (granted) in
                if !granted {
                    self.completeCurrentCall(isUserInitiated: true)
                    self.alertNoMicrophonePermission()
                }
            }
        case .denied:
            try handleIncomingCall(data: data, reportIncomingCallToInterface: false)
            self.completeCurrentCall(isUserInitiated: false)
            self.alertNoMicrophonePermission()
        case .granted:
            try handleIncomingCall(data: data, reportIncomingCallToInterface: true)
        @unknown default:
            try handleIncomingCall(data: data, reportIncomingCallToInterface: true)
        }
    }
    
    private func handleIncomingCall(data: BlazeMessageData, reportIncomingCallToInterface: Bool) throws {
        guard lineIsIdle else {
            throw CallError.busy
        }
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
        pendingRemoteSdp = sdp
        call = Call(uuid: uuid, opponentUser: user, isOutgoing: false)
        if reportIncomingCallToInterface {
            var isNotificationAuthorized = false
            let semaphore = DispatchSemaphore(value: 0)
            UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                isNotificationAuthorized = settings.authorizationStatus == .authorized
                semaphore.signal()
            }
            semaphore.wait()
            performSynchronouslyOnMainThread {
                UIApplication.homeContainerViewController?.pipController?.pauseAction(self)
                view.reload(user: user)
                view.style = .calling
                view.show()
                if UIApplication.shared.applicationState == .active {
                    vibrator.startVibrating()
                    playRingtone(usesSpeaker: true)
                } else if isNotificationAuthorized {
                    UNUserNotificationCenter.current().sendCallNotification(callerName: user.fullName)
                    vibrator.startVibrating()
                    playRingtone(usesSpeaker: true)
                }
            }
        }
    }
    
    private func handleCallStatusChangeIfNeeded(data: BlazeMessageData) {
        guard let call = call, data.quoteMessageId == call.uuidString else {
            return
        }
        if call.isOutgoing, data.category == MessageCategory.WEBRTC_AUDIO_ANSWER.rawValue, let sdpString = data.data.base64Decoded(), let sdp = RTCSessionDescription(jsonString: sdpString) {
            invalidateUnansweredTimeoutTimerAndSetNil()
            self.ringtonePlayer?.stop()
            self.usesSpeaker = false
            call.hasReceivedRemoteAnswer = true
            DispatchQueue.main.sync {
                self.view.style = .connecting
            }
            rtcClient.set(remoteSdp: sdp) { (error) in
                if let error = error {
                    self.queue.async {
                        self.failCurrentCall(sendFailedMesasgeToRemote: true,
                                             reportAction: "Set remote answer",
                                             description: error.localizedDescription)
                    }
                }
            }
        } else if let category = MessageCategory(rawValue: data.category), CallManager.completeCallCategories.contains(category) {
            ringtonePlayer?.stop()
            DispatchQueue.main.sync {
                view.style = .disconnecting
            }
            CallManager.insertCallCompletedMessage(call: call, isUserInitiated: false, category: category)
            clean()
        }
    }
    
    private func handleIncomingIceCandidateIfNeeded(data: BlazeMessageData) {
        guard let call = call, data.quoteMessageId == call.uuidString else {
            return
        }
        guard let candidatesString = data.data.base64Decoded() else {
            return
        }
        [RTCIceCandidate](jsonString: candidatesString).forEach(rtcClient.add)
    }
    
}

extension CallManager: WebRTCClientDelegate {
    
    func webRTCClient(_ client: WebRTCClient, didGenerateLocalCandidate candidate: RTCIceCandidate) {
        guard call != nil else {
            return
        }
        sendCandidates([candidate])
    }
    
    func webRTCClientDidConnected(_ client: WebRTCClient) {
        call?.connectedDate = Date()
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        performSynchronouslyOnMainThread {
            self.view.style = .connected
        }
    }
    
    func webRTCClientDidFailed(_ client: WebRTCClient) {
        queue.async {
            self.failCurrentCall(sendFailedMesasgeToRemote: true,
                                 reportAction: "RTC Client fail",
                                 description: "")
        }
    }
    
}

extension CallManager {
    
    private var portOverride: AVAudioSession.PortOverride {
        return self.usesSpeaker ? .speaker : .none
    }
    
    @objc private func unansweredTimeout() {
        guard let call = call, !call.hasReceivedRemoteAnswer else {
            return
        }
        view.dismiss()
        rtcClient.close()
        isMuted = false
        queue.async {
            self.ringtonePlayer?.stop()
            let msg = Message.createWebRTCMessage(conversationId: call.conversationId,
                                                  category: .WEBRTC_AUDIO_CANCEL,
                                                  status: .SENDING,
                                                  quoteMessageId: call.uuidString)
            SendMessageService.shared.sendWebRTCMessage(message: msg, recipientId: call.opponentUser.userId)
            CallManager.insertCallCompletedMessage(call: call, isUserInitiated: false, category: .WEBRTC_AUDIO_CANCEL)
            self.call = nil
        }
    }
    
    @objc private func audioSessionRouteChange(_ notification: Notification) {
        guard call != nil else {
            return
        }
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(portOverride)
    }
    
    private func alertNetworkFailureOrLineBusy() {
        DispatchQueue.main.async {
            if !WebSocketService.shared.isConnected {
                AppDelegate.current.window.rootViewController?.alert(Localized.CALL_NO_NETWORK)
            } else if !self.lineIsIdle {
                AppDelegate.current.window.rootViewController?.alert(Localized.CALL_HINT_ON_ANOTHER_CALL)
            }
        }
    }
    
    private func alertNoMicrophonePermission() {
        DispatchQueue.main.async {
            AppDelegate.current.window.rootViewController?.alertSettings(Localized.CALL_NO_MICROPHONE_PERMISSION)
        }
    }
    
    private func call(opponentUser: UserItem) {
        AudioManager.shared.pause()
        queue.async {
            guard WebSocketService.shared.isConnected && self.lineIsIdle else {
                self.alertNetworkFailureOrLineBusy()
                return
            }
            DispatchQueue.main.sync {
                self.view.style = .calling
                self.view.reload(user: opponentUser)
                self.view.show()
            }
            let uuid = UUID()
            let call = Call(uuid: uuid, opponentUser: opponentUser, isOutgoing: true)
            let conversationId = call.conversationId
            self.call = call
            let timer = Timer(timeInterval: CallManager.unansweredTimeoutInterval,
                              target: self,
                              selector: #selector(self.unansweredTimeout),
                              userInfo: nil,
                              repeats: false)
            RunLoop.main.add(timer, forMode: .default)
            self.unansweredTimer = timer
            self.playRingtone(usesSpeaker: false)
            self.rtcClient.offer { (sdp, error) in
                guard let sdp = sdp else {
                    self.queue.async {
                        self.failCurrentCall(sendFailedMesasgeToRemote: false,
                                             reportAction: "SDP Construction",
                                             description: error.debugDescription)
                    }
                    return
                }
                guard let content = sdp.jsonString else {
                    self.queue.async {
                        self.failCurrentCall(sendFailedMesasgeToRemote: false,
                                             reportAction: "SDP Serialization",
                                             description: sdp.debugDescription)
                    }
                    return
                }
                let msg = Message.createWebRTCMessage(messageId: call.uuidString,
                                                      conversationId: conversationId,
                                                      category: .WEBRTC_AUDIO_OFFER,
                                                      content: content,
                                                      status: .SENDING)
                SendMessageService.shared.sendMessage(message: msg, ownerUser: opponentUser, isGroupMessage: false)
            }
        }
    }
    
    private func failCurrentCall(sendFailedMesasgeToRemote: Bool, reportAction action: String, description: String) {
        guard let call = call else {
            return
        }
        if sendFailedMesasgeToRemote {
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
        UIApplication.traceError(code: ReportErrorCode.callVoiceError, userInfo: ["action": action, "error": description])
    }
    
    private func sendCandidates(_ candidates: [RTCIceCandidate]) {
        guard let call = call, let content = candidates.jsonString else {
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
    
    private func invalidateUnansweredTimeoutTimerAndSetNil() {
        unansweredTimer?.invalidate()
        unansweredTimer = nil
    }
    
    private func clean() {
        rtcClient.close()
        call = nil
        pendingRemoteSdp = nil
        isMuted = false
        usesSpeaker = false
        invalidateUnansweredTimeoutTimerAndSetNil()
        performSynchronouslyOnMainThread {
            vibrator.stopVibrating()
            view.dismiss()
        }
    }
    
    private func playRingtone(usesSpeaker: Bool) {
        if usesSpeaker {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        } else {
            try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: [])
        }
        ringtonePlayer?.play()
    }
    
}

extension CallManager {
    
    class Vibrator {
        
        private var isVibrating = false
        private var timer: Timer?
        private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?
        
        func startVibrating() {
            guard !isVibrating else {
                return
            }
            backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                self.endBackgroundTask()
            })
            isVibrating = true
            let timer = Timer(timeInterval: 1, repeats: true, block: { (_) in
                AudioServicesPlaySystemSoundWithCompletion(kSystemSoundID_Vibrate, nil)
            })
            timer.fire()
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        
        func stopVibrating() {
            guard isVibrating else {
                return
            }
            endBackgroundTask()
            timer?.invalidate()
            timer = nil
            isVibrating = false
        }
        
        private func endBackgroundTask() {
            guard let id = backgroundTaskIdentifier else {
                return
            }
            UIApplication.shared.endBackgroundTask(id)
            backgroundTaskIdentifier = nil
        }
    }
    
}
