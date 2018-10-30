import Foundation
import WebRTC
import CallKit

class CallManager {
    
    static let shared = CallManager()
    
    private let rtcClient = WebRTCClient()
    private let unansweredTimeoutInterval: TimeInterval = 60
    private let queue = DispatchQueue(label: "one.mixin.messenger.call-manager")
    private let ringtonePlayer = try? AVAudioPlayer(contentsOf: Bundle.main.url(forResource: "Ringtone", withExtension: "m4r")!)
    
    private(set) var call: Call?
    
    private(set) lazy var view: CallView = performSynchronouslyOnMainThread {
        let view = CallView(effect: UIBlurEffect(style: .dark))
        view.manager = self
        return view
    }
    
    private var unansweredTimeoutTimer: Timer?
    private var pendingRemoteSdp: RTCSessionDescription?
    private var pendingCandidates = [RTCIceCandidate]()
    private var canMakeCalls: Bool {
        return CallManager.callObserver.calls.isEmpty
            && AVAudioSession.sharedInstance().recordPermission == .granted
            && WebSocketService.shared.connected
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
        RTCSetMinDebugLogLevel(.error)
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
    
    func call(opponentUser: UserItem) {
        guard canMakeCalls else {
            alertCantMakeCalls()
            return
        }
        view.style = .calling
        view.reload(user: opponentUser)
        view.show()
        let uuid = UUID()
        let call = Call(uuid: uuid, opponentUser: opponentUser, isOutgoing: true)
        let conversationId = call.conversationId
        self.call = call
        unansweredTimeoutTimer = Timer.scheduledTimer(timeInterval: unansweredTimeoutInterval,
                                                      target: self,
                                                      selector: #selector(unansweredTimeout),
                                                      userInfo: nil,
                                                      repeats: false)
        queue.async {
            self.playRingtone(usesSpeaker: false)
            self.rtcClient.offer { (sdp, error) in
                guard let sdp = sdp else {
                    self.failCurrentCall(sendFailedMesasgeToRemote: false,
                                         reportAction: "SDP Construction",
                                         description: error.debugDescription)
                    return
                }
                guard let content = sdp.jsonString else {
                    self.failCurrentCall(sendFailedMesasgeToRemote: false,
                                         reportAction: "SDP Serialization",
                                         description: sdp.debugDescription)
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
    
    func completeCurrentCall() {
        guard let call = call else {
            view.style = .disconnecting
            view.dismiss()
            return
        }
        invalidateUnansweredTimeoutTimerAndSetNil()
        view.style = .disconnecting
        let category: MessageCategory
        if rtcClient.iceConnectionState == .connected {
            category = .WEBRTC_AUDIO_END
        } else if call.isOutgoing {
            category = .WEBRTC_AUDIO_CANCEL
        } else {
            category = .WEBRTC_AUDIO_DECLINE
        }
        queue.async {
            self.ringtonePlayer?.stop()
            self.rtcClient.close()
            let msg = Message.createWebRTCMessage(conversationId: call.conversationId,
                                                  category: category,
                                                  status: .SENDING,
                                                  quoteMessageId: call.uuidString)
            SendMessageService.shared.sendWebRTCMessage(message: msg, recipientId: call.opponentUser.userId)
            CallManager.insertCallCompletedMessage(call: call, category: category)
            DispatchQueue.main.async {
                self.view.dismiss()
                self.isMuted = false
                self.usesSpeaker = false
                self.call = nil
            }
        }
    }
    
    func handleIncomingCall(data: BlazeMessageData) throws {
        guard canMakeCalls else {
            alertCantMakeCalls()
            throw CallError.permissionDenied
        }
        guard call == nil else {
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
        pendingRemoteSdp = sdp
        call = Call(uuid: uuid, opponentUser: user, isOutgoing: false)
        performSynchronouslyOnMainThread {
            view.reload(user: user)
            view.style = .calling
            view.show()
        }
        playRingtone(usesSpeaker: true)
    }
    
    func acceptCurrentCall() {
        guard let call = call, let sdp = pendingRemoteSdp else {
            return
        }
        queue.async {
            self.ringtonePlayer?.stop()
            self.usesSpeaker = false
            self.rtcClient.set(remoteSdp: sdp) { (error) in
                if let error = error {
                    self.failCurrentCall(sendFailedMesasgeToRemote: true,
                                         reportAction: "Set remote Sdp",
                                         description: error.localizedDescription)
                } else {
                    self.rtcClient.answer(completion: { (sdp, error) in
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
                    })
                }
            }
        }
    }
    
    // Return true if data is handled, false if not
    func handleCallStatusChange(data: BlazeMessageData) -> Bool {
        guard let call = call, data.quoteMessageId == call.uuidString else {
            return false
        }
        if call.isOutgoing, data.category == MessageCategory.WEBRTC_AUDIO_ANSWER.rawValue, let sdpString = data.data.base64Decoded(), let sdp = RTCSessionDescription(jsonString: sdpString) {
            invalidateUnansweredTimeoutTimerAndSetNil()
            self.ringtonePlayer?.stop()
            self.usesSpeaker = false
            call.hasReceivedRemoteAnswer = true
            sendCandidates(pendingCandidates)
            rtcClient.set(remoteSdp: sdp) { (error) in
                if let error = error {
                    self.failCurrentCall(sendFailedMesasgeToRemote: true,
                                         reportAction: "Set remote answer",
                                         description: error.localizedDescription)
                }
            }
            return true
        } else if let category = MessageCategory(rawValue: data.category), CallManager.completeCallCategories.contains(category) {
            ringtonePlayer?.stop()
            performSynchronouslyOnMainThread {
                view.style = .disconnecting
            }
            CallManager.insertCallCompletedMessage(call: call,
                                                   completeByUserId: data.userId,
                                                   category: category)
            self.clean()
            performSynchronouslyOnMainThread {
                view.dismiss()
            }
            return true
        } else {
            return false
        }
    }
    
    func handleIncomingIceCandidateIfNeeded(data: BlazeMessageData) {
        guard let call = call, data.quoteMessageId == call.uuidString else {
            return
        }
        guard let candidatesString = data.data.base64Decoded() else {
            return
        }
        [RTCIceCandidate](jsonString: candidatesString).forEach(rtcClient.add)
    }
    
}

extension CallManager {
    
    private static let callObserver = CXCallObserver()
    private static let completeCallCategories: [MessageCategory] = [
        .WEBRTC_AUDIO_END,
        .WEBRTC_AUDIO_BUSY,
        .WEBRTC_AUDIO_CANCEL,
        .WEBRTC_AUDIO_FAILED,
        .WEBRTC_AUDIO_DECLINE
    ]
    
    static func insertCallCompletedMessage(call: Call, completeByUserId userId: String = AccountAPI.shared.accountUserId, category: MessageCategory?) {
        let timeIntervalSinceNow = call.connectedDate?.timeIntervalSinceNow ?? 0
        let duration = abs(timeIntervalSinceNow * millisecondsPerSecond)
        let category = category ?? .WEBRTC_AUDIO_FAILED
        let shouldMarkMessageAsRead = userId == AccountAPI.shared.accountUserId || category == .WEBRTC_AUDIO_END
        let status: MessageStatus = shouldMarkMessageAsRead ? .READ : .DELIVERED
        let msg = Message.createWebRTCMessage(conversationId: call.conversationId,
                                              userId: userId,
                                              category: category,
                                              mediaDuration: Int64(duration),
                                              status: status)
        MessageDAO.shared.insertMessage(message: msg, messageSource: "")
    }
    
    static func insertOfferAndSendWebRTCBusyMessage(against data: BlazeMessageData) {
        insertOfferAndSendWebRTCMessage(against: data, category: .WEBRTC_AUDIO_BUSY)
    }
    
    static func insertOfferAndSendWebRTCFailedMessage(against data: BlazeMessageData) {
        insertOfferAndSendWebRTCMessage(against: data, category: .WEBRTC_AUDIO_FAILED)
    }
    
    private static func insertOfferAndSendWebRTCMessage(against data: BlazeMessageData, category: MessageCategory) {
        let messageToInsert = Message.createWebRTCMessage(data: data, category: category, status: .DELIVERED)
        MessageDAO.shared.insertMessage(message: messageToInsert, messageSource: "")
        let messageToSend = Message.createWebRTCMessage(quote: data, category: category, status: .SENDING)
        SendMessageService.shared.sendWebRTCMessage(message: messageToSend, recipientId: data.getSenderId())
    }
    
}

extension CallManager: WebRTCClientDelegate {
    
    func webRTCClient(_ client: WebRTCClient, didGenerateLocalCandidate candidate: RTCIceCandidate) {
        guard let call = call else {
            return
        }
        if call.isOutgoing, !call.hasReceivedRemoteAnswer {
            pendingCandidates.append(candidate)
        } else {
            sendCandidates([candidate])
        }
    }
    
    func webRTCClientDidConnected(_ client: WebRTCClient) {
        call?.connectedDate = Date()
        performSynchronouslyOnMainThread {
            self.view.style = .connected
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
        DispatchQueue.global().async {
            let msg = Message.createWebRTCMessage(conversationId: call.conversationId,
                                                  category: .WEBRTC_AUDIO_CANCEL,
                                                  status: .SENDING,
                                                  quoteMessageId: call.uuidString)
            SendMessageService.shared.sendWebRTCMessage(message: msg, recipientId: call.opponentUser.userId)
            CallManager.insertCallCompletedMessage(call: call, category: .WEBRTC_AUDIO_CANCEL)
            self.call = nil
        }
    }
    
    @objc private func audioSessionRouteChange(_ notification: Notification) {
        guard call != nil else {
            return
        }
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(portOverride)
    }
    
    private func alertCantMakeCalls() {
        let recordPermission = AVAudioSession.sharedInstance().recordPermission
        if !CallManager.callObserver.calls.isEmpty {
            AppDelegate.current.window?.rootViewController?.alert(Localized.CALL_HINT_ON_ANOTHER_CALL)
        } else if recordPermission == .undetermined {
            AVAudioSession.sharedInstance().requestRecordPermission { (_) in }
        } else if recordPermission == .denied {
            AppDelegate.current.window?.rootViewController?.alertSettings(Localized.PERMISSION_DENIED_MICROPHONE)
        } else if !WebSocketService.shared.connected {
            AppDelegate.current.window?.rootViewController?.alert(Localized.TOAST_API_ERROR_NETWORK_CONNECTION_LOST)
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
        let failedMessage = Message.createWebRTCMessage(conversationId: call.conversationId,
                                                        category: .WEBRTC_AUDIO_FAILED,
                                                        status: .DELIVERED)
        MessageDAO.shared.insertMessage(message: failedMessage, messageSource: "")
        clean()
        UIApplication.trackError("CallManager", action: action, userInfo: ["error": description])
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
        unansweredTimeoutTimer?.invalidate()
        unansweredTimeoutTimer = nil
    }
    
    private func clean() {
        rtcClient.close()
        call = nil
        pendingRemoteSdp = nil
        pendingCandidates = []
        isMuted = false
        usesSpeaker = false
        invalidateUnansweredTimeoutTimerAndSetNil()
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
