import Foundation
import WebRTC

protocol WebRTCClientDelegate: class {
    func webRTCClient(_ client: WebRTCClient, didGenerateLocalCandidate candidate: RTCIceCandidate)
    func webRTCClientDidConnected(_ client: WebRTCClient)
    func webRTCClientDidFailed(_ client: WebRTCClient)
}

class WebRTCClient: NSObject {
    
    weak var delegate: WebRTCClientDelegate?
    
    private let audioId = "audio0"
    private let streamId = "stream0"
    private let factory = RTCPeerConnectionFactory(encoderFactory: RTCDefaultVideoEncoderFactory(),
                                                   decoderFactory: RTCDefaultVideoDecoderFactory())
    
    private var peerConnection: RTCPeerConnection?
    private var audioTrack: RTCAudioTrack?
    
    var iceConnectionState: RTCIceConnectionState {
        return peerConnection?.iceConnectionState ?? .closed
    }
    
    var isMuted = false {
        didSet {
            audioTrack?.isEnabled = !isMuted
        }
    }
    
    func offer(completion: @escaping (RTCSessionDescription?, Error?) -> Void) {
        makePeerConnectionIfNeeded()
        let constraints = RTCMediaConstraints(mandatoryConstraints: [:], optionalConstraints: nil)
        peerConnection?.offer(for: constraints) { (sdp, error) in
            if let sdp = sdp {
                self.peerConnection?.setLocalDescription(sdp, completionHandler: { (_) in
                    completion(sdp, nil)
                })
            } else {
                completion(nil, error)
            }
        }
    }
    
    func answer(completion: @escaping (RTCSessionDescription?, Error?) -> Void) {
        makePeerConnectionIfNeeded()
        let constraints = RTCMediaConstraints(mandatoryConstraints: [:], optionalConstraints: nil)
        peerConnection?.answer(for: constraints) { (sdp, error) in
            if let sdp = sdp {
                self.peerConnection?.setLocalDescription(sdp, completionHandler: { (_) in
                    completion(sdp, nil)
                })
            } else {
                completion(nil, error)
            }
        }
    }
    
    func set(remoteSdp: RTCSessionDescription, completion: @escaping (Error?) -> Void) {
        makePeerConnectionIfNeeded()
        peerConnection?.setRemoteDescription(remoteSdp, completionHandler: completion)
    }
    
    func add(remoteCandidate: RTCIceCandidate) {
        peerConnection?.add(remoteCandidate)
    }
    
    func close() {
        RTCAudioSession.sharedInstance().isAudioEnabled = false
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
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        if newState == .connected {
            delegate?.webRTCClientDidConnected(self)
            RTCAudioSession.sharedInstance().isAudioEnabled = true
        } else if newState == .failed {
            delegate?.webRTCClientDidFailed(self)
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        delegate?.webRTCClient(self, didGenerateLocalCandidate: candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        
    }
    
}

extension WebRTCClient {
    
    private var sharedConfig: RTCConfiguration {
        let config = RTCConfiguration()
        config.iceServers = RTCIceServer.sharedServers
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        return config
    }
    
    private func makePeerConnectionIfNeeded() {
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
        peerConnection.add(audioTrack, streamIds: [streamId])
        peerConnection.delegate = self
        self.peerConnection = peerConnection
        self.audioTrack = audioTrack
    }
    
}
