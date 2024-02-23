import Foundation

public class MixinService {
    
    public enum UserInfoKey {
        public static let messageId = "mid"
        public static let conversationId = "cid"
        public static let userId = "uid"
        public static let sessionId = "sid"
        public static let progress = "prog"
        public static let command = "cmd"
    }
    
    public static let willRecallMessageNotification = Notification.Name(rawValue: "one.mixin.services.will.recall.msg")
    public static let messageReadStatusDidChangeNotification = Notification.Name(rawValue: "one.mixin.services.msg.read.did.change")
    public static let clockSkewDetectedNotification = Notification.Name(rawValue: "one.mixin.services.clock.skew.detected")
    
    public static var callMessageCoordinator: CallMessageCoordinator!

    public static var isStopProcessMessages = false

    @Synchronized(value: false)
    public internal(set) var processing: Bool
    
    internal var currentAccountId: String {
        return myUserId
    }

    public func checkSessionSenderKey(conversationId: String) throws {
        var participants = ParticipantSessionDAO.shared.getNotSendSessionParticipants(conversationId: conversationId, sessionId: LoginManager.shared.account?.sessionID ?? "")
        guard participants.count > 0 else {
            return
        }

        if participants.contains(where: { $0.sessionId.isEmpty }) {
            reporter.report(error: MixinServicesError.badParticipantSession)
            participants = participants.filter { !$0.sessionId.isEmpty }
            if participants.count == 0 {
                return
            }
        }

        let startTime = Date()
        defer {
            if -startTime.timeIntervalSinceNow > 2 {
                Logger.conversation(id: conversationId).info(category: "CheckSessionSenderKey", message: "Check session costs \(-startTime.timeIntervalSinceNow)s")
            }
        }

        var requestSignalKeyUsers = [BlazeMessageParamSession]()
        var signalKeyMessages = [TransferMessage]()
        for p in participants {
            if SignalProtocol.shared.containsSession(recipient: p.userId, deviceId: SignalProtocol.convertSessionIdToDeviceId(p.sessionId)) {
                let (cipherText, isError) = try SignalProtocol.shared.encryptSenderKey(conversationId: conversationId, recipientId: p.userId, sessionId: p.sessionId)
                if isError {
                    requestSignalKeyUsers.append(BlazeMessageParamSession(userId: p.userId, sessionId: p.sessionId))
                } else {
                    signalKeyMessages.append(TransferMessage(recipientId: p.userId, data: cipherText, sessionId: p.sessionId))
                }
            } else {
                requestSignalKeyUsers.append(BlazeMessageParamSession(userId: p.userId, sessionId: p.sessionId))
            }
        }

        var noKeyList = [BlazeMessageParamSession]()

        if !requestSignalKeyUsers.isEmpty {
            let signalKeys = signalKeysChannel(requestSignalKeyUsers: requestSignalKeyUsers)
            Logger.conversation(id: conversationId).info(category: "CheckSessionSenderKey", message: "Created Signal Keys: \(signalKeys.map { "{\($0.userId ?? "(null)")}" }.joined(separator: ","))")
            var keys = [String]()
            for signalKey in signalKeys {
                guard let recipientId = signalKey.userId else {
                    continue
                }
                try SignalProtocol.shared.processSession(userId: recipientId, key: signalKey)
                let (cipherText, _) = try SignalProtocol.shared.encryptSenderKey(conversationId: conversationId, recipientId: recipientId, sessionId: signalKey.sessionId)
                signalKeyMessages.append(TransferMessage(recipientId: recipientId, data: cipherText, sessionId: signalKey.sessionId))
                keys.append(recipientId)
            }

            noKeyList = requestSignalKeyUsers.filter{!keys.contains($0.userId)}
            if !noKeyList.isEmpty {
                let sentSenderKeys = noKeyList.map {
                    ParticipantSession.Sent(conversationId: conversationId,
                                            userId: $0.userId,
                                            sessionId: $0.sessionId!,
                                            sentToServer: SenderKeyStatus.UNKNOWN.rawValue)
                }
                ParticipantSessionDAO.shared.updateParticipantSessionSent(sentSenderKeys)
            }
        }
        
        guard signalKeyMessages.count > 0 else {
            return
        }
        let checksum = ConversationChecksumCalculator.checksum(conversationId: conversationId)
        let param = BlazeMessageParam(conversationId: conversationId, messages: signalKeyMessages, checksum: checksum)
        let blazeMessage = BlazeMessage(params: param, action: BlazeMessageAction.createSignalKeyMessage.rawValue)
        let (success, _, retry) = deliverNoThrow(blazeMessage: blazeMessage)
        if success {
            let sentSenderKeys = signalKeyMessages.map {
                ParticipantSession.Sent(conversationId: conversationId,
                                        userId: $0.recipientId!,
                                        sessionId: $0.sessionId!,
                                        sentToServer: SenderKeyStatus.SENT.rawValue)
            }
            ParticipantSessionDAO.shared.updateParticipantSessionSent(sentSenderKeys)
        } else if retry {
            return try checkSessionSenderKey(conversationId: conversationId)
        }
        
        let messages = signalKeyMessages.map { tm in
            "\(tm.messageId):\(tm.recipientId ?? ""):\(tm.sessionId ?? "")"
        }
        Logger.conversation(id: conversationId).info(category: "CheckSessionSenderKey", message: "Signal Key Message delivered: \(success), retry: \(retry), messages: \(messages.joined(separator: ", "))")
    }

    internal func syncConversation(conversationId: String) {
        repeat {
            switch ConversationAPI.getConversation(conversationId: conversationId) {
            case let .success(response):
                ParticipantSessionDAO.shared.syncConversationParticipantSession(conversation: response)
                CircleConversationDAO.shared.update(conversation: response)
                return
            case .failure(.unauthorized):
                return
            case .failure:
                checkNetworkAndWebSocket()
            }
        } while true
    }
    
    internal func checkSignalSession(recipientId: String, sessionId: String? = nil) throws -> Bool {
        let deviceId = SignalProtocol.convertSessionIdToDeviceId(sessionId)
        if !SignalProtocol.shared.containsSession(recipient: recipientId, deviceId: deviceId) {
            let signalKeys = signalKeysChannel(requestSignalKeyUsers: [BlazeMessageParamSession(userId: recipientId, sessionId: sessionId)])
            guard signalKeys.count > 0 else {
                Logger.general.error(category: "CheckSignalSession", message: "Got empty signal keys for recipient: \(recipientId), session: \(sessionId)")
                return false
            }
            try SignalProtocol.shared.processSession(userId: recipientId, key: signalKeys[0])
        }
        return true
    }

    @discardableResult
    internal func sendSenderKey(conversationId: String, recipientId: String, sessionId: String) throws -> Bool {
        let signalKeys = signalKeysChannel(requestSignalKeyUsers: [BlazeMessageParamSession(userId: recipientId, sessionId: sessionId)])
        if signalKeys.count > 0 {
            try SignalProtocol.shared.processSession(userId: recipientId, key: signalKeys[0])
        } else {
            Logger.conversation(id: conversationId).info(category: "SendSenderKey", message: "Received no signal key from recipient: \(recipientId)")
            let session = ParticipantSession.Sent(conversationId: conversationId,
                                                  userId: recipientId,
                                                  sessionId: sessionId,
                                                  sentToServer: SenderKeyStatus.UNKNOWN.rawValue)
            ParticipantSessionDAO.shared.insertParticipantSessionSent(session)
            return false
        }

        let (cipherText, isError) = try SignalProtocol.shared.encryptSenderKey(conversationId: conversationId, recipientId: recipientId, sessionId: sessionId)
        guard !isError else {
            return false
        }
        let signalKeyMessages = [TransferMessage(recipientId: recipientId, data: cipherText, sessionId: sessionId)]
        let checksum = ConversationChecksumCalculator.checksum(conversationId: conversationId)
        let param = BlazeMessageParam(conversationId: conversationId, messages: signalKeyMessages, checksum: checksum)
        let blazeMessage = BlazeMessage(params: param, action: BlazeMessageAction.createSignalKeyMessage.rawValue)
        let (success, _, retry) = deliverNoThrow(blazeMessage: blazeMessage)
        if success {
            let session = ParticipantSession.Sent(conversationId: conversationId,
                                                  userId: recipientId,
                                                  sessionId: sessionId,
                                                  sentToServer: SenderKeyStatus.SENT.rawValue)
            ParticipantSessionDAO.shared.insertParticipantSessionSent(session)
        } else if retry {
            return try sendSenderKey(conversationId: conversationId, recipientId: recipientId, sessionId: sessionId)
        }
        let infos: Logger.UserInfo = [
            "message_id": blazeMessage.params?.messageId ?? "",
            "session_id": sessionId,
            "recipient_id": recipientId
        ]
        Logger.conversation(id: conversationId).info(category: "DeliverSenderKey", message: "Sender key is delivered: \(success)", userInfo: infos)
        return success
    }

    func sendNoKeyMessage(conversationId: String, recipientId: String) {
        let plainData = PlainJsonMessagePayload(action: PlainDataAction.NO_KEY.rawValue, messages: nil, ackMessages: nil, content: nil)
        let encoded = (try? JSONEncoder.default.encode(plainData))?.base64EncodedString() ?? ""
        let params = BlazeMessageParam(conversationId: conversationId, recipientId: recipientId, category: MessageCategory.PLAIN_JSON.rawValue, data: encoded, status: MessageStatus.SENDING.rawValue, messageId: UUID().uuidString.lowercased())
        let blazeMessage = BlazeMessage(params: params, action: BlazeMessageAction.createMessage.rawValue)
        SendMessageService.shared.sendMessage(conversationId: conversationId, userId: recipientId, blazeMessage: blazeMessage, action: .SEND_NO_KEY)
    }

    func refreshParticipantSession(conversationId: String, userId: String, retry: Bool) -> Bool {
        Logger.conversation(id: conversationId).info(category: "RefreshSession", message: "Start refreshing session for: \(userId), retry: \(retry)")
        repeat {
            guard LoginManager.shared.isLoggedIn else {
                return false
            }

            switch UserAPI.fetchSessions(userIds: [userId]) {
            case let .success(sessions):
                let participantSessions = sessions.map {
                    ParticipantSession(conversationId: conversationId,
                                       userId: $0.userId,
                                       sessionId: $0.sessionId,
                                       sentToServer: nil,
                                       createdAt: Date().toUTCString(),
                                       publicKey: $0.publicKey)
                }
                UserDatabase.current.save(participantSessions)
                return true
            case .failure(.unauthorized):
                return false
            case .failure:
                if retry {
                    checkNetworkAndWebSocket()
                } else {
                    return false
                }
            }
        } while true
    }

    func signalKeysChannel(requestSignalKeyUsers: [BlazeMessageParamSession]) -> [SignalKey] {
        let blazeMessage = BlazeMessage(params: BlazeMessageParam(consumeSignalKeys: requestSignalKeyUsers), action: BlazeMessageAction.consumeSessionSignalKeys.rawValue)
        return deliverKeys(blazeMessage: blazeMessage)?.toConsumeSignalKeys() ?? []
    }

    @discardableResult
    internal func deliverKeys(blazeMessage: BlazeMessage) -> BlazeMessage? {
        repeat {
            do {
                return try WebSocketService.shared.respondedMessage(for: blazeMessage).blazeMessage
            } catch MixinAPIResponseError.unauthorized {
                return nil
            } catch MixinAPIResponseError.forbidden {
                return nil
            } catch {
                checkNetworkAndWebSocket()
                Thread.sleep(forTimeInterval: 2)
            }
        } while true
    }

    @discardableResult
    internal func deliverNoThrow(blazeMessage: BlazeMessage) -> (success: Bool, responseMessage: BlazeMessage?, retry: Bool) {
        repeat {
            do {
                let response = try WebSocketService.shared.respondedMessage(for: blazeMessage)
                return (response.success, response.blazeMessage, false)
            } catch MixinAPIResponseError.unauthorized {
                return (false, nil, false)
            } catch MixinAPIResponseError.forbidden {
                return (true, nil, false)
            } catch MixinAPIResponseError.invalidConversationChecksum {
                if let conversationId = blazeMessage.params?.conversationId {
                    syncConversation(conversationId: conversationId)
                }
                return (false, nil, true)
            } catch {
                checkNetworkAndWebSocket()
                Thread.sleep(forTimeInterval: 2)
            }
        } while true
    }

    @discardableResult
    internal func deliver(blazeMessage: BlazeMessage) throws -> (success: Bool, responseMessage: BlazeMessage?) {
        var blazeMessage = blazeMessage
        if let conversationId = blazeMessage.params?.conversationId {
            let checksum = ConversationChecksumCalculator.checksum(conversationId: conversationId)
            blazeMessage.params?.conversationChecksum = checksum
        }
        repeat {
            guard LoginManager.shared.isLoggedIn else {
                return (false, nil)
            }
            
            do {
                let response = try WebSocketService.shared.respondedMessage(for: blazeMessage)
                return (response.success, response.blazeMessage)
            } catch let error as MixinAPIResponseError {
                #if DEBUG
                print("======SendMessaegService...deliver...error:\(error)")
                #endif
                switch error {
                case .unauthorized:
                    return (false, nil)
                case .forbidden:
                    return (true, nil)
                case .invalidConversationChecksum:
                    if let conversationId = blazeMessage.params?.conversationId {
                        syncConversation(conversationId: conversationId)
                    }
                    throw error
                default:
                    checkNetworkAndWebSocket()
                    if error.isClientErrorResponse {
                        continue
                    } else {
                        throw error
                    }
                }
            } catch {
                #if DEBUG
                print("======SendMessaegService...deliver...error:\(error)")
                #endif
                reporter.report(error: error)
                Thread.sleep(forTimeInterval: 2)
                return (false, nil)
            }
        } while true
    }

    internal func checkNetworkAndWebSocket() {
        repeat {
            Thread.sleep(forTimeInterval: 2)
        } while LoginManager.shared.isLoggedIn && !MixinService.isStopProcessMessages && (!ReachabilityManger.shared.isReachable || !WebSocketService.shared.isConnected)
    }

    internal func checkNetwork() {
        repeat {
            Thread.sleep(forTimeInterval: 2)
        } while LoginManager.shared.isLoggedIn && !MixinService.isStopProcessMessages && !ReachabilityManger.shared.isReachable
    }
    
    public func stopRecallMessage(item: MessageItem, childMessageIds: [String]? = nil) {
        let messageId = item.messageId
        let category = item.category
        UNUserNotificationCenter.current().removeNotifications(withIdentifiers: [messageId])
        
        let userInfo = [SendMessageService.UserInfoKey.conversationId: item.conversationId,
                        SendMessageService.UserInfoKey.messageId: messageId]
        DispatchQueue.main.sync {
            NotificationCenter.default.post(name: SendMessageService.willRecallMessageNotification, object: self, userInfo: userInfo)
        }
        
        let jobIds: [String]
        if ["_IMAGE", "_DATA", "_AUDIO", "_VIDEO"].contains(where: category.hasSuffix) {
            jobIds = [AttachmentDownloadJob.jobId(transcriptId: nil, messageId: item.messageId)]
        } else if category.hasSuffix("_TRANSCRIPT") {
            let childMessageIds = childMessageIds ?? TranscriptMessageDAO.shared.childrenMessageIds(transcriptId: messageId)
            jobIds = childMessageIds.map { transcriptMessageId in
                AttachmentDownloadJob.jobId(transcriptId: messageId, messageId: transcriptMessageId)
            }
        } else {
            jobIds = []
        }
        
        for id in jobIds {
            ConcurrentJobQueue.shared.cancelJob(jobId: id)
        }
        
        if let mediaUrl = item.mediaUrl {
            AttachmentContainer.removeMediaFiles(mediaUrl: mediaUrl, category: category)
        }
        if category.hasSuffix("_TRANSCRIPT") {
            AttachmentContainer.removeAll(transcriptId: messageId)
        }
    }
    
}
