import Foundation
import CallKit
import WebRTC
import MixinServices

class GroupCall: Call {
    
    enum Subscription: Equatable {
        
        case myself
        case user(String)
        
        var userId: String {
            switch self {
            case .myself:
                return myUserId
            case .user(let id):
                return id
            }
        }
        
    }
    
    static let maxNumberOfMembers = 256
    static let maxNumberOfKrakenRetries: UInt = 30
    
    let conversation: ConversationItem
    let conversationName: String
    let membersDataSource: GroupCallMembersDataSource
    
    private let retryInterval: DispatchTimeInterval = .seconds(3)
    private let speakingStatusPollingInterval: TimeInterval = 0.6
    private let messenger = KrakenMessageRetriever()
    
    private var frameKey: Data?
    private var trackId: String?
    private var pendingInvitees: [UserItem] // Invite and clear after first connection
    private var pendingCandidates: [String] = []
    private var inviteeTimers: Set<Timer> = []
    private var endCallCompletions: [() -> Void] = []
    
    private var inviters: [UserItem] {
        didSet {
            assert(queue.isCurrent)
            guard self.internalState == .incoming, !inviters.isEmpty else {
                return
            }
            let name = Self.localizedInvitationName(inviters: inviters)
            DispatchQueue.main.sync {
                self.localizedName = name
            }
        }
    }
    
    private weak var speakingTimer: Timer?
    
    override var cxHandle: CXHandle {
        CXHandle(type: .generic, value: conversationId)
    }
    
    init(conversation: ConversationItem, isOutgoing: Bool, inviters: [UserItem], invitees: [UserItem]) {
        let conversationName = conversation.getConversationName()
        let localizedName: String = isOutgoing ? conversationName : Self.localizedInvitationName(inviters: inviters)
        
        self.conversation = conversation
        self.conversationName = conversationName
        self.membersDataSource = GroupCallMembersDataSource(conversationId: conversation.conversationId,
                                                            inviters: inviters,
                                                            invitees: invitees)
        self.inviters = inviters
        self.pendingInvitees = invitees
        super.init(uuid: UUID(),
                   conversationId: conversation.conversationId,
                   isOutgoing: isOutgoing,
                   state: isOutgoing ? .outgoing : .incoming,
                   localizedName: localizedName)
        
        self.messenger.delegate = self
        self.rtcClient.delegate = self
        Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] Initialized with cid: \(conversation.conversationId)")
        self.initializeFrameKey()
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
            Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] End with reason: \(reason), side: \(side)")
            DispatchQueue.main.sync {
                self.invalidateUnansweredTimer()
                for timer in self.inviteeTimers {
                    timer.invalidate()
                }
                self.rtcClient.close(permanently: true)
            }
            if side == .local {
                switch reason {
                case .declined:
                    for userId in self.inviters.map(\.userId) {
                        let decline = KrakenRequest(callUUID: self.uuid,
                                                    conversationId: self.conversationId,
                                                    trackId: self.trackId,
                                                    action: .decline(recipientId: userId),
                                                    retryOnFailure: true)
                        self.messenger.request(decline)
                    }
                case .cancelled:
                    let message = Message.createKrakenMessage(conversationId: self.conversationId,
                                                              userId: myUserId,
                                                              category: .KRAKEN_CANCEL,
                                                              createdAt: Date().toUTCString())
                    MessageDAO.shared.insertMessage(message: message, messageSource: "GroupCall")
                    let cancel = KrakenRequest(callUUID: self.uuid,
                                               conversationId: self.conversationId,
                                               trackId: self.trackId,
                                               action: .cancel,
                                               retryOnFailure: true)
                    self.messenger.request(cancel)
                default:
                    let end = KrakenRequest(callUUID: self.uuid,
                                            conversationId: self.conversationId,
                                            trackId: self.trackId,
                                            action: .end,
                                            retryOnFailure: true)
                    self.messenger.request(end)
                }
            }
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
    
    override func scheduleUnansweredTimer() {
        super.scheduleUnansweredTimer()
        assert(!isOutgoing, "Do not schedule unanswered timer for outgoing group calls. Invitees should have their own timers")
    }
    
    func appendInviter(with userId: String) {
        queue.async {
            guard self.internalState != .disconnecting else {
                return
            }
            guard !self.inviters.contains(where: { $0.userId == userId }) else {
                return
            }
            guard let inviter = UserDAO.shared.getUser(userId: userId) else {
                return
            }
            self.inviters.append(inviter)
        }
    }
    
    func reportCancel(fromUserWith userId: String, createdAt: String) {
        queue.async {
            guard self.internalState != .disconnecting else {
                return
            }
            if let index = self.inviters.firstIndex(where: { $0.userId == userId }) {
                self.inviters.remove(at: index)
                if self.internalState == .incoming && self.inviters.isEmpty {
                    self.end(reason: .cancelled, by: .remote)
                }
            } else {
                DispatchQueue.main.sync {
                    self.membersDataSource.reportStopInviting(with: userId)
                }
                let message = Message.createKrakenMessage(conversationId: self.conversationId,
                                                          userId: userId,
                                                          category: .KRAKEN_CANCEL,
                                                          createdAt: createdAt)
                MessageDAO.shared.insertMessage(message: message, messageSource: "GroupCall")
            }
        }
    }
    
    func invite(members: [UserItem]) {
        guard !members.isEmpty else {
            return
        }
        queue.autoAsync {
            guard let trackId = self.trackId else {
                assertionFailure()
                return
            }
            let inCallMemberIds = CallService.shared.membersManager.requestMemberIds(forConversationWith: self.conversationId)
            let filteredMembers = members.filter { item in
                !inCallMemberIds.contains(item.userId)
            }
            guard !filteredMembers.isEmpty else {
                return
            }
            let userIds = filteredMembers.map(\.userId)
            Logger.call.info(category: "GroupCall", message: "Inviting: \(filteredMembers.map(\.fullName))")
            DispatchQueue.main.sync {
                self.membersDataSource.reportInviting(with: filteredMembers)
                let timer = Timer.scheduledTimer(timeInterval: Call.timeoutInterval,
                                                 target: self,
                                                 selector: #selector(self.invitingTimedOut(_:)),
                                                 userInfo: userIds,
                                                 repeats: false)
                self.inviteeTimers.insert(timer)
            }
            let invitation = KrakenRequest(callUUID: self.uuid,
                                           conversationId: self.conversationId,
                                           trackId: trackId,
                                           action: .invite(recipients: userIds),
                                           retryOnFailure: true)
            self.messenger.request(invitation)
        }
    }
    
    func reportDecline(fromUserWith userId: String, createdAt: String) {
        queue.async {
            guard self.internalState != .disconnecting else {
                return
            }
            DispatchQueue.main.sync {
                self.membersDataSource.reportStopInviting(with: userId)
            }
            let message = Message.createKrakenMessage(conversationId: self.conversationId,
                                                      userId: userId,
                                                      category: .KRAKEN_DECLINE,
                                                      createdAt: createdAt)
            MessageDAO.shared.insertMessage(message: message, messageSource: "GroupCall")
        }
    }
    
    func reportEnd(fromUserWith userId: String) {
        queue.async {
            guard self.internalState != .disconnecting else {
                return
            }
            DispatchQueue.main.sync {
                self.membersDataSource.removeMember(with: userId, onlyIfNotConnected: false)
            }
        }
    }
    
}

extension GroupCall {
    
    func beginSpeakingStatusPolling() {
        assert(Thread.isMainThread)
        guard speakingTimer == nil else {
            return
        }
        let timer = Timer.scheduledTimer(withTimeInterval: speakingStatusPollingInterval, repeats: true, block: { [weak self] _ in
            self?.rtcClient.audioLevels(completion: { levels in
                self?.membersDataSource.updateMembers(with: levels)
            })
        })
        speakingTimer = timer
    }
    
    func endSpeakingStatusPolling() {
        assert(Thread.isMainThread)
        speakingTimer?.invalidate()
        speakingTimer = nil
        membersDataSource.updateMembers(with: [:])
    }
    
}

extension GroupCall {
    
    @objc private func senderKeyDidChange(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let conversationId = userInfo[ReceiveMessageService.UserInfoKey.conversationId] as? String,
            self.conversationId == conversationId
        else {
            return
        }
        let userId = userInfo[ReceiveMessageService.UserInfoKey.userId] as? String
        let sessionId = userInfo[ReceiveMessageService.UserInfoKey.sessionId] as? String
        queue.async {
            Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] Updating sender key for uid: \(userId ?? "(null)"), sid: \(sessionId ?? "(null)")")
            if let userId = userId, !userId.isEmpty {
                if let sessionId = sessionId, !sessionId.isEmpty {
                    let frameKey = SignalProtocol.shared.getSenderKeyPublic(groupId: conversationId, userId: userId, sessionId: sessionId)?.dropFirst()
                    self.rtcClient.setFrameDecryptorKey(frameKey, forReceiverWith: userId, sessionId: sessionId) { (isTrackEnabled) in
                        self.membersDataSource.setMember(with: userId, isTrackDisabled: !isTrackEnabled)
                    }
                } else {
                    try? ReceiveMessageService.shared.checkSessionSenderKey(conversationId: conversationId)
                }
            } else {
                try? ReceiveMessageService.shared.checkSessionSenderKey(conversationId: conversationId)
                self.frameKey = SignalProtocol.shared.getSenderKeyPublic(groupId: conversationId, userId: myUserId)?.dropFirst()
                if let key = self.frameKey {
                    self.rtcClient.setFrameEncryptorKey(key)
                } else {
                    Logger.call.error(category: "GroupCall", message: "[\(self.uuidString)] SignalProtocol reports no sender key")
                }
            }
        }
    }
    
    @objc private func invitingTimedOut(_ timer: Timer) {
        guard let userIds = timer.userInfo as? [String] else {
            return
        }
        userIds.forEach(membersDataSource.reportStopInviting(with:))
        inviteeTimers.remove(timer)
    }
    
}

extension GroupCall {
    
    func connect(isRestarting: Bool, completion: @escaping Call.Completion) {
        Queue.main.autoSync {
            // The call starts to connect from now, but the `state` property is updated in self.queue right
            // after internalState is updated. Therefore, if any UI components access `state` synchornouly
            // after connect, it will find an `incoming` as state.
            // For correct UI display, change `state` here first
            if self.state != .disconnecting {
                self.state = isRestarting ? .restarting : .connecting
            }
            invalidateUnansweredTimer()
            self.localizedName = self.conversationName
        }
        queue.autoAsync {
            guard self.internalState != .disconnecting else {
                return
            }
            self.internalState = isRestarting ? .restarting : .connecting
            DispatchQueue.main.async {
                self.membersDataSource.setMember(with: myUserId, isConnected: false)
            }
            self.rtcClient.offer(key: self.frameKey, restartIce: isRestarting) { result in
                switch result {
                case .failure(let error):
                    Logger.call.error(category: "GroupCall", message: "[\(self.uuidString)] Failed to make offer: \(error)")
                    completion(error)
                case .success(let sdp):
                    Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] Will fetch track ID")
                    let trackId = self.queue.sync { self.trackId }
                    Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] Track ID ready")
                    let publish = KrakenRequest(callUUID: self.uuid,
                                                conversationId: self.conversationId,
                                                trackId: trackId,
                                                action: isRestarting ? .restart(sdp: sdp) : .publish(sdp: sdp),
                                                retryOnFailure: true)
                    switch self.request(publish) {
                    case let .failure(error):
                        switch error {
                        case .peerNotFound, .trackNotFound:
                            // These two errors are not likely to show up here. However, rebuild it is always safe
                            Logger.call.warn(category: "GroupCall", message: "[\(self.uuidString)] Failed to publish: \(error)")
                            fallthrough
                        case .peerClosed:
                            self.rebuild()
                            completion(nil)
                        default:
                            Logger.call.error(category: "GroupCall", message: "[\(self.uuidString)] Failed to publish: \(error)")
                            completion(error)
                        }
                    case let .success((trackId, sdp)):
                        self.queue.async {
                            Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] Got track id from publish response")
                            self.trackId = trackId
                            self.rtcClient.setRemoteSDP(sdp) { error in
                                if let error = error {
                                    Logger.call.error(category: "GroupCall", message: "[\(self.uuidString)] Failed to set remote SDP: \(error)")
                                    completion(error)
                                } else {
                                    completion(nil)
                                    Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] SDP from publish response is set")
                                    self.subscribe(to: .myself)
                                }
                            }
                            for candidate in self.pendingCandidates {
                                let trickle = KrakenRequest(callUUID: self.uuid,
                                                            conversationId: self.conversationId,
                                                            trackId: trackId,
                                                            action: .trickle(candidate: candidate),
                                                            retryOnFailure: true)
                                self.messenger.request(trickle)
                                Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] Request \(trickle.debugDescription)")
                            }
                            self.pendingCandidates = []
                            self.invite(members: self.pendingInvitees)
                            self.pendingInvitees = []
                        }
                    }
                }
            }
        }
    }
    
    func subscribe(to subscription: Subscription) {
        queue.async {
            if case let .user(userId) = subscription, let item = UserDAO.shared.getUser(userId: userId) {
                let member = GroupCallMembersDataSource.Member(item: item, status: nil, isConnected: false)
                DispatchQueue.main.async {
                    self.membersDataSource.addMember(member, onConflict: .discard)
                }
            }
            guard (self.trackId != nil && self.internalState != .restarting) || subscription == .myself else {
                Logger.call.warn(category: "GroupCall", message: "[\(self.uuidString)] Not subscribing: \(subscription), trackId: \(self.trackId ?? "(null)"), internalState: \(self.internalState)")
                return
            }
            let subscribe = KrakenRequest(callUUID: self.uuid,
                                          conversationId: self.conversationId,
                                          trackId: self.trackId,
                                          action: .subscribe,
                                          retryOnFailure: true)
            switch self.request(subscribe) {
            case let .success((_, sdp)) where sdp.type == .offer:
                self.rtcClient.setRemoteSDP(sdp) { error in
                    if let error = error {
                        Logger.call.error(category: "GroupCall", message: "[\(self.uuidString)] Faild to set sdp from subscribe response: \(error)")
                        self.queue.asyncAfter(deadline: .now() + self.retryInterval) {
                            self.subscribe(to: subscription)
                        }
                    } else {
                        Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] SDP from subscribe response is set")
                        let userId = subscription.userId
                        DispatchQueue.main.async {
                            self.membersDataSource.setMember(with: userId, isConnected: true)
                        }
                        self.answer(userId: userId)
                    }
                }
            case .success, .failure(.invalidJSEP):
                DispatchQueue.main.async {
                    self.membersDataSource.setMember(with: subscription.userId, isConnected: true)
                }
                Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] Subscribe responded with a non-offer sdp")
            case .failure(let error):
                switch error {
                case .invalidKrakenResponse:
                    Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] Invalid subscribe response. Drop it")
                case .peerClosed, .invalidTransition:
                    Logger.call.warn(category: "GroupCall", message: "[\(self.uuidString)] Subscribe responded with \(error)")
                    self.rebuild()
                case .peerNotFound, .trackNotFound:
                    Logger.call.warn(category: "GroupCall", message: "[\(self.uuidString)] Subscribe responded with \(error)")
                default:
                    Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] subscribing result reports \(error)")
                    self.end(reason: .failed, by: .local)
                }
            }
        }
    }
    
    private func answer(userId: String) {
        rtcClient.answer { (result) in
            switch result {
            case .success(let sdpJson):
                let answer = KrakenRequest(callUUID: self.uuid,
                                           conversationId: self.conversationId,
                                           trackId: self.trackId,
                                           action: .answer(sdp: sdpJson),
                                           retryOnFailure: true)
                self.messenger.request(answer)
                Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] Request \(answer.debugDescription)")
            case .failure(let error):
                Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] Failed to generate answer: \(error)")
                self.queue.asyncAfter(deadline: .now() + self.retryInterval) {
                    guard self.state != .disconnecting else {
                        return
                    }
                    self.answer(userId: userId)
                }
            }
        }
    }
    
    // Group call is rebuilt when a request is responded with 5002002 peerClosed
    private func rebuild() {
        queue.async {
            guard self.internalState != .disconnecting else {
                return
            }
            Logger.call.error(category: "GroupCall", message: "[\(self.uuidString)] Rebuilding")
            self.internalState = .restarting
            DispatchQueue.main.sync {
                self.rtcClient.close(permanently: false)
            }
            self.trackId = nil
            self.pendingCandidates = []
            self.connect(isRestarting: false) { error in
                guard let error = error else {
                    return
                }
                Logger.call.error(category: "GroupCall", message: "[\(self.uuidString)] Failed to rebuild call: \(error)")
                self.rebuild()
            }
        }
    }
    
}

extension GroupCall: KrakenMessageRetrieverDelegate {
    
    func krakenMessageRetriever(
        _ retriever: KrakenMessageRetriever,
        shouldRetryRequest request: KrakenRequest,
        error: Swift.Error,
        numberOfRetries: UInt
    ) -> Bool {
        guard LoginManager.shared.isLoggedIn else {
            return false
        }
        guard internalState != .disconnecting else {
            Logger.call.info(category: "GroupCall", message: "Call is disconnecting, give up kraken request")
            return false
        }
        switch error {
        case MixinAPIError.unauthorized:
            Logger.call.info(category: "GroupCall", message: "Got 401 when requesting: \(request.debugDescription)")
            self.end(reason: .failed, by: .local)
            return false
        case MixinAPIError.peerNotFound, MixinAPIError.peerClosed, MixinAPIError.trackNotFound, MixinAPIError.roomFull, MixinAPIError.invalidTransition:
            return false
        default:
            let shouldRetry = numberOfRetries < Self.maxNumberOfKrakenRetries
            Logger.call.info(category: "GroupCall", message: "got error: \(error), numberOfRetries: \(numberOfRetries), returns shouldRetry: \(shouldRetry)")
            return shouldRetry
        }
    }
    
}

extension GroupCall: WebRTCClientDelegate {
    
    func webRTCClient(_ client: WebRTCClient, didGenerateLocalCandidate candidate: RTCIceCandidate) {
        guard let json = candidate.jsonString?.base64Encoded() else {
            return
        }
        queue.async {
            if let trackId = self.trackId, self.internalState != .restarting {
                let trickle = KrakenRequest(callUUID: self.uuid,
                                            conversationId: self.conversationId,
                                            trackId: trackId,
                                            action: .trickle(candidate: json),
                                            retryOnFailure: true)
                self.messenger.request(trickle) // FIXME: Handle errors
                Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] Request \(trickle.debugDescription)")
            } else {
                self.pendingCandidates.append(json)
            }
        }
    }
    
    func webRTCClientDidConnected(_ client: WebRTCClient) {
        queue.async {
            guard self.internalState != .disconnecting else {
                Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] WebRTCClient reports connected on disconnecting state. Ignore it")
                return
            }
            DispatchQueue.main.sync {
                self.membersDataSource.setMember(with: myUserId, isConnected: true)
                if self.connectedDate == nil {
                    self.connectedDate = Date()
                }
            }
            self.internalState = .connected
        }
    }
    
    func webRTCClientDidDisconnected(_ client: WebRTCClient) {
        
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeIceConnectionStateTo newState: RTCIceConnectionState) {
        let stateDescription: String
        switch newState {
        case .new:
            stateDescription = "new"
        case .checking:
            stateDescription = "checking"
        case .connected:
            stateDescription = "connected"
        case .completed:
            stateDescription = "completed"
        case .failed:
            stateDescription = "failed"
        case .disconnected:
            stateDescription = "disconnected"
        case .closed:
            stateDescription = "closed"
        case .count:
            stateDescription = "count"
        @unknown default:
            stateDescription = "\(newState.rawValue)"
        }
        Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] ICE connection state: \(stateDescription)")
        queue.async {
            guard self.internalState == .connected, newState == .failed else {
                return
            }
            Logger.call.warn(category: "GroupCall", message: "[\(self.uuidString)] Restarting call because ICE connection failed")
            self.internalState = .restarting
            self.connect(isRestarting: true) { error in
                guard let error = error else {
                    return
                }
                Logger.call.error(category: "GroupCall", message: "[\(self.uuidString)] Failed to restart: \(error)")
                self.rebuild()
            }
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, senderPublicKeyForUserWith userId: String, sessionId: String) -> Data? {
        SignalProtocol.shared.getSenderKeyPublic(groupId: conversationId, userId: userId, sessionId: sessionId)?.dropFirst()
    }
    
    func webRTCClient(_ client: WebRTCClient, didAddReceiverWith streamId: StreamId, trackDisabled: Bool) {
        DispatchQueue.main.async {
            CallService.shared.membersManager.addMember(with: streamId.userId, toConversationWith: self.conversationId)
            self.membersDataSource.setMember(with: streamId.userId, isConnected: true)
            self.membersDataSource.setMember(with: streamId.userId, isTrackDisabled: trackDisabled)
        }
        if trackDisabled {
            Logger.call.warn(category: "GroupCall", message: "[\(self.uuidString)] Request resend key for track disabled stream: \(streamId)")
            ReceiveMessageService.shared.requestResendKey(conversationId: conversationId, recipientId: streamId.userId, sessionId: streamId.sessionId)
        }
    }
    
}

extension GroupCall {
    
    private static func localizedInvitationName(inviters: [UserItem]) -> String {
        let names = inviters.map(\.fullName).joined(separator: ", ")
        return R.string.localizable.chat_group_call_invite(names)
    }
    
    private func initializeFrameKey() {
        Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] Initializing frame key")
        queue.async {
            let cid = self.conversationId
            try? ReceiveMessageService.shared.checkSessionSenderKey(conversationId: cid)
            self.frameKey = SignalProtocol.shared.getSenderKeyPublic(groupId: cid, userId: myUserId)?.dropFirst()
            Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] Frame key initialized: \(self.frameKey?.count ?? -1)")
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(self.senderKeyDidChange(_:)),
                                                   name: ReceiveMessageService.senderKeyDidChangeNotification,
                                                   object: nil)
        }
    }
    
    private func request(_ request: KrakenRequest) -> Result<(trackId: String, sdp: RTCSessionDescription), CallError> {
        Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] Request \(request.debugDescription)")
        switch messenger.request(request) {
        case .success(let data):
            guard let responseData = Data(base64Encoded: data.data) else {
                Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] invalid response data: \(data.data)")
                return .failure(.invalidKrakenResponse)
            }
            guard let data = try? JSONDecoder.default.decode(KrakenPublishResponse.self, from: responseData) else {
                let response = String(data: responseData, encoding: .utf8) ?? (responseData as NSData).debugDescription
                Logger.call.info(category: "GroupCall", message: "[\(self.uuidString)] invalid KrakenPublishResponse: \(response)")
                return .failure(.invalidKrakenResponse)
            }
            if let sdpString = data.jsep.base64Decoded(), let sdp = RTCSessionDescription(jsonString: sdpString) {
                return .success((data.trackId, sdp))
            } else {
                return .failure(.invalidJSEP)
            }
        case let .failure(error):
            switch error {
            case MixinAPIError.roomFull:
                return .failure(.roomFull)
            case MixinAPIError.peerNotFound:
                return .failure(.peerNotFound)
            case MixinAPIError.peerClosed:
                return .failure(.peerClosed)
            case MixinAPIError.trackNotFound:
                return .failure(.trackNotFound)
            case MixinAPIError.invalidTransition:
                return .failure(.invalidTransition)
            default:
                return .failure(.networkFailure)
            }
        }
    }
    
}
