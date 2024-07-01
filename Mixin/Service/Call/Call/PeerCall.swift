import Foundation
import CallKit
import WebRTC
import MixinServices

class PeerCall: Call {
    
    let remoteUserId: String
    let remoteUsername: String
    
    var remoteUser: UserItem?
    
    private var endCallCompletions: [() -> Void] = []
    
    override var cxHandle: CXHandle {
        CXHandle(type: .generic, value: remoteUserId)
    }
    
    init(uuid: UUID, remoteUserId: String, remoteUsername: String, isOutgoing: Bool, state: State) {
        self.remoteUserId = remoteUserId
        self.remoteUsername = remoteUsername
        let conversationId = ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: remoteUserId)
        super.init(uuid: uuid,
                   conversationId: conversationId,
                   isOutgoing: isOutgoing,
                   state: state,
                   localizedName: remoteUsername)
    }
    
    override func end(reason: EndedReason, by side: EndedSide, completion: (() -> Void)? = nil) {
        queue.async {
            guard self.internalState != .disconnecting else {
                if let completion = completion {
                    self.endCallCompletions.append(completion)
                }
                return
            }
            self.internalState = .disconnecting
            Logger.call.info(category: "PeerCall", message: "[\(self.uuidString)] End with reason: \(reason), side: \(side)")
            DispatchQueue.main.sync {
                self.invalidateUnansweredTimer()
                self.rtcClient.close(permanently: true)
            }
            
            let category: MessageCategory
            let markLocalMessageRead: Bool
            switch reason {
            case .busy:
                category = .WEBRTC_AUDIO_BUSY
                switch side {
                case .local:
                    markLocalMessageRead = false
                case .remote:
                    markLocalMessageRead = true
                }
            case .declined:
                category = .WEBRTC_AUDIO_DECLINE
                switch side {
                case .local:
                    markLocalMessageRead = false
                case .remote:
                    markLocalMessageRead = false
                }
            case .cancelled:
                category = .WEBRTC_AUDIO_CANCEL
                switch side {
                case .local:
                    markLocalMessageRead = true
                case .remote:
                    markLocalMessageRead = false
                }
            case .ended:
                category = .WEBRTC_AUDIO_END
                switch side {
                case .local:
                    markLocalMessageRead = true
                case .remote:
                    markLocalMessageRead = true
                }
            case .failed:
                category = .WEBRTC_AUDIO_FAILED
                switch side {
                case .local:
                    markLocalMessageRead = false
                case .remote:
                    markLocalMessageRead = false
                }
            }
            
            if side == .local {
                let end = Message.createWebRTCMessage(conversationId: self.conversationId,
                                                      category: category,
                                                      status: .SENDING,
                                                      quoteMessageId: self.uuidString)
                SendMessageService.shared.sendWebRTCMessage(message: end,
                                                            recipientId: self.remoteUserId)
            }
            let timeIntervalSinceNow: TimeInterval = DispatchQueue.main.sync {
                self.connectedDate?.timeIntervalSinceNow ?? 0
            }
            let duration = Int64(abs(timeIntervalSinceNow * millisecondsPerSecond))
            let status: MessageStatus = markLocalMessageRead ? .READ : .DELIVERED
            let end = Message.createWebRTCMessage(messageId: self.uuidString,
                                                  conversationId: self.conversationId,
                                                  userId: self.isOutgoing ? myUserId : self.remoteUserId,
                                                  category: category,
                                                  mediaDuration: duration,
                                                  status: status)
            let expireIn = ConversationDAO.shared.getExpireIn(conversationId: self.conversationId) ?? 0
            MessageDAO.shared.insertMessage(message: end, messageSource: MessageDAO.LocalMessageSource.peerCall, expireIn: expireIn)
            
            let userInfo: [String: Any] = [
                Self.UserInfoKey.endedReason: reason,
                Self.UserInfoKey.endedSide: side
            ]
            DispatchQueue.main.sync {
                NotificationCenter.default.post(name: Self.didEndNotification,
                                                object: self,
                                                userInfo: userInfo)
            }
            
            for completion in self.endCallCompletions {
                completion()
            }
            completion?()
        }
    }
    
}

// MARK: - ICE Candidates
extension PeerCall {
    
    func addRemoteCandidates(_ candidates: [RTCIceCandidate]) {
        assert(!candidates.isEmpty, "Check emptiness before adding")
        candidates.forEach(rtcClient.addRemoteCandidates)
    }
    
    func sendLocalCandidate(_ candidate: RTCIceCandidate) {
        guard let content = [candidate].jsonString else {
            Logger.call.error(category: "PeerCall", message: "[\(self.uuidString)] Unable to serialize candidate: \(candidate)")
            return
        }
        let candidate = Message.createWebRTCMessage(conversationId: conversationId,
                                                    category: .WEBRTC_ICE_CANDIDATE,
                                                    content: content,
                                                    status: .SENDING,
                                                    quoteMessageId: uuidString)
        DispatchQueue.main.async {
            guard let remoteUser = self.remoteUser else {
                Logger.call.error(category: "PeerCall", message: "[\(self.uuidString)] Missing remote user when sending candidates")
                return
            }
            SendMessageService.shared.sendMessage(message: candidate,
                                                  ownerUser: remoteUser,
                                                  isGroupMessage: false)
        }
    }
    
}
