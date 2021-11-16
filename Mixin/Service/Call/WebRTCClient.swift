import Foundation
import WebRTC
import MixinServices

protocol WebRTCClientDelegate: AnyObject {
    func webRTCClient(_ client: WebRTCClient, didGenerateLocalCandidate candidate: RTCIceCandidate)
    func webRTCClientDidConnected(_ client: WebRTCClient)
    func webRTCClientDidDisconnected(_ client: WebRTCClient)
    func webRTCClient(_ client: WebRTCClient, didChangeIceConnectionStateTo newState: RTCIceConnectionState)
    
    // Group call only
    func webRTCClient(_ client: WebRTCClient, senderPublicKeyForUserWith userId: String, sessionId: String) -> Data?
    func webRTCClient(_ client: WebRTCClient, didAddReceiverWith userId: String, trackDisabled: Bool)
}

class WebRTCClient: NSObject {
    
    private static let audioId = "audio0"
    private static let streamId = "stream0"
    
    weak var delegate: WebRTCClientDelegate?
    
    var isMuted = false {
        didSet {
            assert(Thread.isMainThread)
            audioTrack?.isEnabled = !isMuted
        }
    }
    
    private(set) var trackDisabledUserIds: Set<String> = []
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.WebRTCClient")
    
    private var isClosed = false
    private var peerConnection: RTCPeerConnection?
    private var audioTrack: RTCAudioTrack?
    private var pendingCandidates: [RTCIceCandidate] = []
    
    private var rtpSender: RTCRtpSender?
    private var rtpReceivers: [String: RTCRtpReceiver] = [:] // Access on self.queue
    
    // Key is track id, value is user id
    // RTCPeerConnection call delegate functions in its private signaling queue, including
    // completionHandler of the statistics API. Despite the writing and reading happens on
    // the same queue de facto, there's no documentation that gurantees this behavior.
    // To prevent any potential data races, we dispatch any r/w to our queue
    private var tracksUserId: [String: String] = [:]
    
    func offer(
        key: Data?,
        withIceRestartConstraint: Bool,
        completion: @escaping (Result<String, CallError>) -> Void
    ) {
        guard let connection = loadPeerConnection(key: key) else {
            // loadPeerConnection returns nil when self is closed or released,
            // it's OK to just return here without calling completion
            return
        }
        let mandatoryConstraints: [String: String]
        if withIceRestartConstraint {
            mandatoryConstraints = [kRTCMediaConstraintsIceRestart: kRTCMediaConstraintsValueTrue]
        } else {
            mandatoryConstraints = [:]
        }
        let constraints = RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints,
                                              optionalConstraints: nil)
        connection.offer(for: constraints) { sdp, error in
            self.queue.async {
                if let sdp = sdp, let json = sdp.jsonString {
                    connection.setLocalDescription(sdp) { error in
                        DispatchQueue.main.async {
                            self.addPendingCandidate(to: connection)
                        }
                        self.queue.async {
                            completion(.success(json))
                        }
                    }
                } else {
                    completion(.failure(.offerConstruction(error)))
                }
            }
        }
    }
    
    func answer(completion: @escaping (Result<String, CallError>) -> Void) {
        guard let connection = loadPeerConnection(key: nil) else {
            // loadPeerConnection returns nil when self is closed or released,
            // it's OK to just return here without calling completion
            return
        }
        let constraints = RTCMediaConstraints(mandatoryConstraints: [:], optionalConstraints: nil)
        connection.answer(for: constraints) { sdp, error in
            self.queue.async {
                guard let sdp = sdp, let json = sdp.jsonString else {
                    completion(.failure(.answerConstruction(error)))
                    return
                }
                connection.setLocalDescription(sdp) { error in
                    DispatchQueue.main.async {
                        self.addPendingCandidate(to: connection)
                    }
                    self.queue.async {
                        completion(.success(json))
                    }
                }
            }
        }
    }
    
    func setRemoteSDP(_ sdp: RTCSessionDescription, completion: @escaping Call.Completion) {
        guard let connection = loadPeerConnection(key: nil) else {
            // loadPeerConnection returns nil when self is closed or released,
            // it's OK to just return here without calling completion
            return
        }
        connection.setRemoteDescription(sdp, completionHandler: { error in
            self.queue.async {
                completion(error)
            }
        })
    }
    
    func addRemoteCandidates(_ candidate: RTCIceCandidate) {
        assert(Thread.isMainThread)
        if let connection = peerConnection {
            addCandidate(candidate, to: connection)
        } else {
            pendingCandidates.append(candidate)
        }
    }
    
    func setFrameEncryptorKey(_ key: Data) {
        Queue.main.autoSync {
            guard let sender = self.rtpSender else {
                Logger.call.error(category: "WebRTCClient", message: "Set encrypt key: \(key.count) bytes but finds no sender")
                return
            }
            sender.setFrameEncryptorKey(key)
            Logger.call.info(category: "WebRTCClient", message: "Set encrypt key: \(key.count) bytes for myself")
        }
    }
    
    func setFrameDecryptorKey(_ key: Data?, forReceiverWith userId: String, sessionId: String, completion: @escaping (_ isTrackEnabled: Bool) -> Void) {
        queue.async {
            let streamId = StreamId(userId: userId, sessionId: sessionId).rawValue
            Logger.call.info(category: "WebRTCClient", message: "Set decrypt key: \(key?.count ?? -1) bytes for uid: \(userId), sid: \(sessionId)")
            guard let receiver = self.rtpReceivers[streamId] else {
                Logger.call.warn(category: "WebRTCClient", message: "No such receiver")
                return
            }
            let hasKey: Bool
            if let key = key {
                hasKey = true
                receiver.setFrameDecryptorKey(key)
            } else {
                hasKey = false
            }
            receiver.track?.isEnabled = hasKey
            DispatchQueue.main.sync {
                if hasKey {
                    _ = self.trackDisabledUserIds.remove(userId)
                }
                completion(hasKey)
            }
        }
    }
    
    func audioLevels(completion: @escaping ([String: Double]) -> Void) {
        assert(Thread.isMainThread)
        let isAudioTrackEnabled = audioTrack?.isEnabled ?? false
        peerConnection?.statistics() { report in
            // See self.tracksUserId for queue dispatching
            self.queue.async {
                var audioLevels: [String: Double] = [:]
                for (key, value) in report.statistics {
                    if key.hasPrefix("RTCMediaStreamTrack_sender_") {
                        if isAudioTrackEnabled {
                            guard
                                let mediaSourceId = value.values["mediaSourceId"] as? String,
                                let source = report.statistics[mediaSourceId],
                                let level = source.values["audioLevel"] as? Double
                            else {
                                continue
                            }
                            audioLevels[myUserId] = level
                        } else {
                            audioLevels[myUserId] = 0
                        }
                    } else if key.hasPrefix("RTCMediaStreamTrack_receiver_") {
                        guard
                            let trackId = value.values["trackIdentifier"] as? String,
                            let userId = self.tracksUserId[trackId],
                            let level = value.values["audioLevel"] as? Double
                        else {
                            continue
                        }
                        audioLevels[userId] = level
                    }
                }
                DispatchQueue.main.async {
                    completion(audioLevels)
                }
            }
        }
    }
    
    func close() {
        assert(Thread.isMainThread)
        isClosed = true
        peerConnection?.close()
        peerConnection = nil
        audioTrack = nil
        rtpSender = nil
        pendingCandidates = []
        queue.async { [weak self] in
            self?.rtpReceivers = [:]
        }
    }
    
    private func addCandidate(_ candidate: RTCIceCandidate, to connection: RTCPeerConnection) {
        connection.add(candidate) { error in
            if let error = error {
                Logger.call.error(category: "WebRTCClient", message: "Failed to add candidate: \(error)")
            }
        }
    }
    
    private func addPendingCandidate(to connection: RTCPeerConnection) {
        assert(Thread.isMainThread)
        guard !pendingCandidates.isEmpty else {
            return
        }
        for candidate in pendingCandidates {
            addCandidate(candidate, to: connection)
        }
        pendingCandidates = []
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
        delegate?.webRTCClient(self, didChangeIceConnectionStateTo: newState)
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
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        switch newState {
        case .connected:
            delegate?.webRTCClientDidConnected(self)
        case .disconnected:
            delegate?.webRTCClientDidDisconnected(self)
        default:
            break
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams mediaStreams: [RTCMediaStream]) {
        let streamIds = mediaStreams
            .map(\.streamId)
            .compactMap(StreamId.init(rawValue:))
            .filter({ $0.userId != myUserId })
        assert(streamIds.count <= 1)
        if streamIds.count > 1 {
            Logger.call.warn(category: "WebRTCClient", message: "RtpReceiver: \(rtpReceiver) comes with multiple streams: \(streamIds)")
        }
        guard let id = streamIds.first else {
            Logger.call.error(category: "WebRTCClient", message: "RtpReceiver: \(rtpReceiver) comes with empty stream")
            return
        }
        let frameKey = delegate?.webRTCClient(self, senderPublicKeyForUserWith: id.userId, sessionId: id.sessionId)
        let disableTrack = frameKey == nil
        if let frameKey = frameKey {
            rtpReceiver.setFrameDecryptorKey(frameKey)
            Logger.call.info(category: "WebRTCClient", message: "Set decrypt key: \(frameKey.count) bytes for stream: \(id)")
        } else {
            Logger.call.warn(category: "WebRTCClient", message: "No decrypt key for stream: \(id)")
        }
        if let track = rtpReceiver.track {
            track.isEnabled = !disableTrack
        }
        queue.sync {
            self.rtpReceivers[id.rawValue] = rtpReceiver
            if let trackId = rtpReceiver.track?.trackId {
                self.tracksUserId[trackId] = id.userId
            }
            if disableTrack {
                DispatchQueue.main.sync {
                    _ = self.trackDisabledUserIds.insert(id.userId)
                }
            }
        }
        delegate?.webRTCClient(self, didAddReceiverWith: id.userId, trackDisabled: disableTrack)
    }
    
}

extension WebRTCClient {
    
    private func loadIceServers(completion: @escaping ([RTCIceServer]) -> Void) {
        CallAPI.turn(queue: queue) { [weak self] result in
            switch result {
            case let .success(servers):
                let iceServers = servers.map {
                    RTCIceServer(urlStrings: [$0.url], username: $0.username, credential: $0.credential)
                }
                completion(iceServers)
            case let .failure(error):
                Logger.call.error(category: "WebRTCClient", message: "ICE Server fetching fails: \(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    guard let self = self, !self.isClosed else {
                        return
                    }
                    self.loadIceServers(completion: completion)
                }
            }
        }
    }
    
    // Returns nil only when self is closed or released
    private func loadPeerConnection(key: Data?) -> RTCPeerConnection? {
        var result = DispatchQueue.main.sync {
            self.peerConnection
        }
        if let connection = result {
            return connection
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        loadIceServers { [weak self] iceServers in
            let config = RTCConfiguration()
            config.tcpCandidatePolicy = .enabled
            config.iceTransportPolicy = .relay
            config.bundlePolicy = .maxBundle
            config.rtcpMuxPolicy = .require
            config.sdpSemantics = .unifiedPlan
            config.iceServers = iceServers
            config.continualGatheringPolicy = .gatherOnce
            
            let factory = RTCPeerConnectionFactory(encoderFactory: RTCDefaultVideoEncoderFactory(),
                                                   decoderFactory: RTCDefaultVideoDecoderFactory())
            let mediaConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: [:])
            let peerConnection = factory.peerConnection(with: config, constraints: mediaConstraints, delegate: nil)
            let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
            let audioSource = factory.audioSource(with: audioConstraints)
            let audioTrack = factory.audioTrack(with: audioSource, trackId: Self.audioId)
            
            let rtpSender = peerConnection?.add(audioTrack, streamIds: [Self.streamId])
            if let key = key {
                rtpSender?.setFrameEncryptorKey(key)
                Logger.call.info(category: "WebRTCClient", message: "Set encrypt key: \(key.count) bytes for myself")
            } else {
                Logger.call.warn(category: "WebRTCClient", message: "No encrypt key for myself")
            }
            peerConnection?.delegate = self
            
            DispatchQueue.main.sync {
                guard let self = self, !self.isClosed else {
                    return
                }
                guard let rtpSender = rtpSender, let peerConnection = peerConnection else {
                    Logger.call.error(category: "WebRTCClient", message: "Failed to generate peer connection")
                    return
                }
                if self.isMuted {
                    audioTrack.isEnabled = false
                }
                self.rtpSender = rtpSender
                self.peerConnection = peerConnection
                self.audioTrack = audioTrack
                result = peerConnection
            }
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }
    
}
