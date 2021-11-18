import Foundation
import WebRTC
import MixinServices

class OutgoingPeerCall: PeerCall {
    
    init(uuid: UUID, remoteUser: UserItem) {
        super.init(uuid: uuid,
                   remoteUserId: remoteUser.userId,
                   remoteUsername: remoteUser.fullName,
                   isOutgoing: true,
                   state: .outgoing)
        self.rtcClient.delegate = self
        self.remoteUser = remoteUser
    }
    
}

// MARK: - WebRTCClientDelegate
extension OutgoingPeerCall: WebRTCClientDelegate {
    
    func webRTCClient(_ client: WebRTCClient, didGenerateLocalCandidate candidate: RTCIceCandidate) {
        sendLocalCandidate(candidate)
    }
    
    func webRTCClientDidConnected(_ client: WebRTCClient) {
        queue.async {
            guard self.internalState != .disconnecting else {
                return
            }
            DispatchQueue.main.sync {
                guard self.connectedDate == nil else {
                    return
                }
                self.connectedDate = Date()
            }
            self.internalState = .connected
        }
    }
    
    func webRTCClientDidDisconnected(_ client: WebRTCClient) {
        
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeIceConnectionStateTo newState: RTCIceConnectionState) {
        queue.async {
            guard newState == .failed else {
                return
            }
            Logger.call.warn(category: "OutgoingPeerCall", message: "[\(self.uuidString)] WebRTC client reports ICE connection failed")
            guard self.internalState == .connected else {
                return
            }
            self.internalState = .restarting
            Logger.call.info(category: "PeerCall", message: "[\(self.uuidString)] Restarting the call")
            self.rtcClient.offer(key: nil, restartIce: true) { result in
                switch result {
                case .success(let sdp):
                    let offer = Message.createWebRTCMessage(messageId: UUID().uuidString.lowercased(),
                                                            conversationId: self.conversationId,
                                                            userId: myUserId,
                                                            category: .WEBRTC_AUDIO_OFFER,
                                                            content: sdp,
                                                            mediaDuration: nil,
                                                            status: .SENDING,
                                                            quoteMessageId: self.uuidString)
                    SendMessageService.shared.sendMessage(message: offer,
                                                          ownerUser: self.remoteUser,
                                                          isGroupMessage: false)
                case .failure(let error):
                    Logger.call.error(category: "PeerCall", message: "[\(self.uuidString)] Failed to generate restarting offer: \(error)")
                    self.end(reason: .failed, by: .local)
                }
            }
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, senderPublicKeyForUserWith userId: String, sessionId: String) -> Data? {
        nil
    }
    
    func webRTCClient(_ client: WebRTCClient, didAddReceiverWith userId: String, trackDisabled: Bool) {
        
    }
    
}

// MARK: - Transactions
extension OutgoingPeerCall {
    
    func sendOffer(completion: @escaping Call.Completion) {
        queue.async {
            guard self.internalState == .outgoing else {
                completion(CallError.invalidState(description: "sendOffer with: \(self.internalState)"))
                return
            }
            let remoteUser = DispatchQueue.main.sync { self.remoteUser }
                ?? UserDAO.shared.getUser(userId: self.remoteUserId)
            guard let remoteUser = remoteUser else {
                completion(CallError.missingUser(userId: self.remoteUserId))
                return
            }
            DispatchQueue.main.sync {
                self.remoteUser = remoteUser
            }
            self.scheduleUnansweredTimer()
            self.rtcClient.offer(key: nil, restartIce: false) { result in
                switch result {
                case .success(let sdp):
                    let offer = Message.createWebRTCMessage(messageId: self.uuidString,
                                                            conversationId: self.conversationId,
                                                            category: .WEBRTC_AUDIO_OFFER,
                                                            content: sdp,
                                                            status: .SENDING)
                    SendMessageService.shared.sendMessage(message: offer,
                                                          ownerUser: remoteUser,
                                                          isGroupMessage: false)
                    completion(nil)
                case .failure(let error):
                    completion(error)
                }
            }
        }
    }
    
    func takeRemoteAnswer(sdp: RTCSessionDescription, completion: @escaping Call.Completion) {
        queue.async {
            guard self.internalState == .outgoing else {
                completion(CallError.invalidState(description: "takeRemoteAnswer with: \(self.internalState)"))
                return
            }
            self.invalidateUnansweredTimer()
            self.rtcClient.setRemoteSDP(sdp) { error in
                if let error = error {
                    completion(error)
                } else {
                    self.queue.async {
                        self.internalState = .connecting
                        completion(nil)
                    }
                }
            }
        }
    }
    
}
