import Foundation
import WebRTC
import MixinServices

class IncomingPeerCall: PeerCall {
    
    private var isUserAccepted = false
    private var remoteSDP: RTCSessionDescription?
    private var answerCompletion: ((Error?) -> Void)?
    
    init(uuid: UUID, remoteUserId: String, remoteUsername: String) {
        super.init(uuid: uuid,
                   remoteUserId: remoteUserId,
                   remoteUsername: remoteUsername,
                   isOutgoing: false,
                   state: .incoming)
        rtcClient.delegate = self
    }
    
    convenience init(uuid: UUID, remoteUser: UserItem) {
        self.init(uuid: uuid,
                  remoteUserId: remoteUser.userId,
                  remoteUsername: remoteUser.fullName)
        self.remoteUser = remoteUser
    }
    
    override func end(reason: EndedReason, by side: EndedSide, completion: (() -> Void)? = nil) {
        super.end(reason: reason, by: side) {
            if let completion = self.answerCompletion {
                Logger.call.info(category: "IncomingPeerCall", message: "[\(self.uuidString)] Ended with answer callback awaiting")
                completion(CallError.invalidState(description: "Already ended"))
                self.answerCompletion = nil
            }
            completion?()
        }
    }
    
}

// MARK: - WebRTCClientDelegate
extension IncomingPeerCall: WebRTCClientDelegate {
    
    func webRTCClient(_ client: WebRTCClient, didGenerateLocalCandidate candidate: RTCIceCandidate) {
        sendLocalCandidate(candidate)
    }
    
    func webRTCClientDidConnected(_ client: WebRTCClient) {
        queue.async {
            guard self.internalState != .disconnecting else {
                Logger.call.info(category: "IncomingPeerCall", message: "[\(self.uuidString)] WebRTCClient reports connected on disconnecting state. Ignore it")
                return
            }
            DispatchQueue.main.sync {
                guard self.connectedDate == nil else {
                    return
                }
                self.connectedDate = Date()
            }
            self.internalState = .connected
            if let completion = self.answerCompletion {
                completion(nil)
                self.answerCompletion = nil
            }
        }
    }
    
    func webRTCClientDidDisconnected(_ client: WebRTCClient) {
        
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeIceConnectionStateTo newState: RTCIceConnectionState) {
        queue.async {
            guard newState == .failed else {
                return
            }
            Logger.call.warn(category: "IncomingPeerCall", message: "[\(self.uuidString)] WebRTC client reports ICE connection failed")
            guard self.internalState == .connected else {
                return
            }
            self.internalState = .restarting
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, senderPublicKeyForUserWith userId: String, sessionId: String) -> Data? {
        nil
    }
    
    func webRTCClient(_ client: WebRTCClient, didAddReceiverWith userId: String, trackDisabled: Bool) {
        
    }
    
}

// MARK: - Internal state transactions
extension IncomingPeerCall {
    
    func takeRemoteSDP(_ sdp: RTCSessionDescription, completion: @escaping Call.Completion) {
        queue.async {
            guard [.incoming, .connecting, .restarting].contains(self.internalState) else {
                let description = "takeRemoteSDP with: \(self.internalState)"
                completion(CallError.invalidState(description: description))
                return
            }
            self.remoteSDP = sdp
            if self.isUserAccepted {
                Logger.call.info(category: "IncomingPeerCall", message: "[\(self.uuidString)] User has accepted this call, start connecting now")
                self.connect(with: sdp, completion: completion)
            } else {
                Logger.call.info(category: "IncomingPeerCall", message: "[\(self.uuidString)] Remote SDP is saved, now waits for user to accept")
                self.scheduleUnansweredTimer()
                completion(nil)
            }
        }
    }
    
    func requestAnswer(completion: @escaping Call.Completion) {
        Queue.main.autoSync {
            // The call starts to connect from now, but the `state` property is updated in self.queue right
            // after internalState is updated. Therefore, if any UI components access `state` synchornouly
            // after requestAnswer, it will find an `incoming` as state.
            // For correct UI display, change `state` here first
            self.state = .connecting
        }
        queue.async {
            guard self.internalState == .incoming else {
                let description = "requestAnswer with: \(self.internalState)"
                completion(CallError.invalidState(description: description))
                Logger.call.error(category: "IncomingPeerCall", message: "[\(self.uuidString)] \(description)")
                return
            }
            self.invalidateUnansweredTimer()
            self.queue.async {
                self.internalState = .connecting
            }
            if let sdp = self.remoteSDP {
                Logger.call.info(category: "IncomingPeerCall", message: "[\(self.uuidString)] Remote SDP is saved before, start connecting now")
                self.connect(with: sdp, completion: completion)
            } else {
                Logger.call.info(category: "IncomingPeerCall", message: "[\(self.uuidString)] User has accepted this call, now waits for remote SDP")
                self.isUserAccepted = true
                completion(nil)
            }
        }
    }
    
}

// MARK: - Private works
extension IncomingPeerCall {
    
    private func connect(with remoteSDP: RTCSessionDescription, completion: @escaping Call.Completion) {
        rtcClient.setRemoteSDP(remoteSDP) { error in
            if let error = error {
                Logger.call.error(category: "IncomingPeerCall", message: "[\(self.uuidString)] Failed to set remote SDP: \(error)")
                completion(CallError.setRemoteSdp(error))
            } else {
                self.rtcClient.answer { result in
                    self.queue.async {
                        guard self.internalState != .disconnecting else {
                            completion(CallError.invalidState(description: "Answering to a disconnecting call"))
                            return
                        }
                        switch result {
                        case.success(let sdp):
                            let answer = Message.createWebRTCMessage(conversationId: self.conversationId,
                                                                     category: .WEBRTC_AUDIO_ANSWER,
                                                                     content: sdp,
                                                                     status: .SENDING,
                                                                     quoteMessageId: self.uuidString)
                            SendMessageService.shared.sendMessage(message: answer,
                                                                  ownerUser: self.remoteUser,
                                                                  isGroupMessage: false)
                            Logger.call.info(category: "IncomingPeerCall", message: "[\(self.uuidString)] Answer is sent")
                            self.answerCompletion = completion
                        case .failure(let error):
                            completion(CallError.answerConstruction(error))
                            Logger.call.error(category: "IncomingPeerCall", message: "[\(self.uuidString)] Failed to construct answer: \(error)")
                        }
                    }
                }
            }
        }
    }
    
}
