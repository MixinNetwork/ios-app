import Foundation
import WebRTC
import MixinServices

protocol WebRTCClientDelegate: class {
    func webRTCClient(_ client: WebRTCClient, didGenerateLocalCandidate candidate: RTCIceCandidate)
    func webRTCClientDidConnected(_ client: WebRTCClient)
    func webRTCClientDidDisconnected(_ client: WebRTCClient)
    func webRTCClient(_ client: WebRTCClient, senderPublicKeyForUserWith userId: String, sessionId: String) -> Data?
}

class WebRTCClient: NSObject {
    
    weak var delegate: WebRTCClientDelegate?
    
    private unowned let queue: DispatchQueue
    
    private let audioId = "audio0"
    private let streamId = "stream0"
    private let factory = RTCPeerConnectionFactory(encoderFactory: RTCDefaultVideoEncoderFactory(),
                                                   decoderFactory: RTCDefaultVideoDecoderFactory())
    
    private(set) var audioTrack: RTCAudioTrack?
    
    private var peerConnection: RTCPeerConnection?
    
    var canAddRemoteCandidate: Bool {
        peerConnection != nil
    }
    
    var iceConnectionState: RTCIceConnectionState {
        return peerConnection?.iceConnectionState ?? .closed
    }
    
    init(delegateQueue: DispatchQueue) {
        self.queue = delegateQueue
        super.init()
    }
    
    func offer(key: Data? = nil, completion: @escaping (Result<String, CallError>) -> Void) {
        makePeerConnectionIfNeeded(key: key)
        let constraints = RTCMediaConstraints(mandatoryConstraints: [:], optionalConstraints: nil)
        peerConnection?.offer(for: constraints) { (sdp, error) in
            if let sdp = sdp, let json = sdp.jsonString {
                self.peerConnection?.setLocalDescription(sdp, completionHandler: { (_) in
                    self.queue.async {
                        completion(.success(json))
                    }
                })
            } else {
                self.queue.async {
                    completion(.failure(.offerConstruction(error)))
                }
            }
        }
    }
    
    func answer(completion: @escaping (Result<String, CallError>) -> Void) {
        makePeerConnectionIfNeeded()
        let constraints = RTCMediaConstraints(mandatoryConstraints: [:], optionalConstraints: nil)
        peerConnection?.answer(for: constraints) { (sdp, error) in
            if let sdp = sdp, let json = sdp.jsonString {
                self.peerConnection?.setLocalDescription(sdp, completionHandler: { (_) in
                    self.queue.async {
                        completion(.success(json))
                    }
                })
            } else {
                self.queue.async {
                    completion(.failure(.answerConstruction(error)))
                }
            }
        }
    }
    
    func set(remoteSdp: RTCSessionDescription, completion: @escaping (Error?) -> Void) {
        makePeerConnectionIfNeeded()
        peerConnection?.setRemoteDescription(remoteSdp, completionHandler: { error in
            self.queue.async {
                completion(error)
            }
        })
    }
    
    func add(remoteCandidate: RTCIceCandidate) {
        peerConnection?.add(remoteCandidate)
    }
    
    func close() {
        peerConnection?.close()
        peerConnection = nil
        audioTrack = nil
    }
    
}

extension WebRTCClient: RTCPeerConnectionDelegate {
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        if newState == .connected {
            queue.async {
                self.delegate?.webRTCClientDidConnected(self)
            }
        } else if newState == .disconnected {
            queue.async {
                self.delegate?.webRTCClientDidDisconnected(self)
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didStartReceivingOn transceiver: RTCRtpTransceiver) {
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams mediaStreams: [RTCMediaStream]) {
        for m in mediaStreams {
            let userSession = m.streamId.components(separatedBy:"~")
            guard userSession.count == 2 else {
                continue
            }
            guard userSession[0] != myUserId else {
                continue
            }
            let frameKey = delegate?.webRTCClient(self,
                                                  senderPublicKeyForUserWith: userSession[0],
                                                  sessionId: userSession[1])
            if let frameKey = frameKey {
                rtpReceiver.setFrameDecryptorKey(frameKey)
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        queue.async {
            self.delegate?.webRTCClient(self, didGenerateLocalCandidate: candidate)
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        
    }
    
}

extension WebRTCClient {
    
    private var sharedConfig: RTCConfiguration {
        let config = RTCConfiguration()
        config.tcpCandidatePolicy = .enabled
        config.iceTransportPolicy = .relay
        config.bundlePolicy = .maxBundle
        config.rtcpMuxPolicy = .require
        config.sdpSemantics = .unifiedPlan
        config.iceServers = RTCIceServer.sharedServers
        config.continualGatheringPolicy = .gatherOnce
        return config
    }
    
    private func makePeerConnectionIfNeeded(key: Data? = nil) {
        guard self.peerConnection == nil else {
            return
        }
        RTCAudioSession.sharedInstance().useManualAudio = true
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: [:])

        let peerConnection = factory.peerConnection(with: sharedConfig,
                                                    constraints: constraints,
                                                    delegate: nil)
        let audioTrack: RTCAudioTrack = {
            let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
            let audioSource = factory.audioSource(with: audioConstraints)
            return factory.audioTrack(with: audioSource, trackId: audioId)
        }()
        let rtpSender = peerConnection.add(audioTrack, streamIds: [streamId])
        if let key = key {
          rtpSender.setFrameEncryptorKey(key)
        }
        peerConnection.delegate = self
        self.peerConnection = peerConnection
        self.audioTrack = audioTrack
    }
    
}
