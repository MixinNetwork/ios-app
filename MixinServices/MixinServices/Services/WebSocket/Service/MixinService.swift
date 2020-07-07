import Foundation

public class MixinService {

    public enum UserInfoKey {
        public static let messageId = "msg_id"
        public static let conversationId = "conv_id"
    }
    
    public static let willRecallMessageNotification = Notification.Name(rawValue: "one.mixin.services.will.recall.msg")
    public static let messageReadStatusDidChangeNotification = Notification.Name(rawValue: "one.mixin.services.msg.read.did.change")
    public static let clockSkewDetectedNotification = Notification.Name(rawValue: "one.mixin.services.clock.skew.detected")
    
    public static var callMessageCoordinator: CallMessageCoordinator!

    public static var isStopProcessMessages = false
    
    public internal(set) var processing = false
    
    internal var currentAccountId: String {
        return myUserId
    }

    public func checkSessionSenderKey(conversationId: String) throws {
        var participants = ParticipantSessionDAO.shared.getNotSendSessionParticipants(conversationId: conversationId, sessionId: LoginManager.shared.account?.session_id ?? "")
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
                Logger.write(conversationId: conversationId, log: "[CheckSessionSenderKey][CheckSessionSenderKey]...check session too slow...\(-startTime.timeIntervalSinceNow)s")
            }
        }

        var requestSignalKeyUsers = [BlazeMessageParamSession]()
        var signalKeyMessages = [TransferMessage]()
        for p in participants {
            if SignalProtocol.shared.containsSession(recipient: p.userId, deviceId: SignalProtocol.convertSessionIdToDeviceId(p.sessionId)) {
                Logger.write(conversationId: conversationId, log: "[CheckSessionSenderKey]...containsSession...\(p.userId)")
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
                let sentSenderKeys = noKeyList.compactMap { ParticipantSession(conversationId: conversationId, userId: $0.userId, sessionId: $0.sessionId!, sentToServer: SenderKeyStatus.UNKNOWN.rawValue, createdAt: Date().toUTCString()) }
                MixinDatabase.shared.insertOrReplace(objects: sentSenderKeys)
            }
            Logger.write(conversationId: conversationId, log: "[CheckSessionSenderKey][SignalKeys]...\(signalKeys.map { "{\($0.userId ?? "")}" }.joined(separator: ","))...")
        }
        
        guard signalKeyMessages.count > 0 else {
            return
        }
        let checksum = ConversationChecksumCalculator.checksum(conversationId: conversationId)
        let param = BlazeMessageParam(conversationId: conversationId, messages: signalKeyMessages, checksum: checksum)
        let blazeMessage = BlazeMessage(params: param, action: BlazeMessageAction.createSignalKeyMessage.rawValue)
        let (success, retry) = deliverNoThrow(blazeMessage: blazeMessage)
        if success {
            let sentSenderKeys = signalKeyMessages.compactMap { ParticipantSession(conversationId: conversationId, userId: $0.recipientId!, sessionId: $0.sessionId!, sentToServer: SenderKeyStatus.SENT.rawValue, createdAt: Date().toUTCString()) }
            MixinDatabase.shared.insertOrReplace(objects: sentSenderKeys)
        } else if retry {
            return try checkSessionSenderKey(conversationId: conversationId)
        }

        Logger.write(conversationId: conversationId, log: "[CheckSessionSenderKey][CreateSignalKeyMessage]...deliver:\(success)...retry:\(retry)...\(signalKeyMessages.map { "{\($0.messageId):\($0.recipientId ?? ""):\($0.sessionId ?? "")}" }.joined(separator: ","))...")
    }

    internal func syncConversation(conversationId: String) {
        repeat {
            switch ConversationAPI.shared.getConversation(conversationId: conversationId) {
            case let .success(response):
                ParticipantSessionDAO.shared.syncConversationParticipantSession(conversation: response)
                CircleConversationDAO.shared.update(conversation: response)
                return
            case let .failure(error):
                if error.code == 401 {
                    return
                }
                checkNetworkAndWebSocket()
            }
        } while true
    }
    
    internal func checkSignalSession(recipientId: String, sessionId: String? = nil) throws -> Bool {
        let deviceId = SignalProtocol.convertSessionIdToDeviceId(sessionId)
        if !SignalProtocol.shared.containsSession(recipient: recipientId, deviceId: deviceId) {
            let signalKeys = signalKeysChannel(requestSignalKeyUsers: [BlazeMessageParamSession(userId: recipientId, sessionId: sessionId)])
            guard signalKeys.count > 0 else {
                Logger.write(log: "[MixinService][CheckSignalSession]...recipientId:\(recipientId)...sessionId:\(sessionId ?? "")...signal keys count is zero ")
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
            Logger.write(conversationId: conversationId, log: "[SendSenderKey]...recipientId:\(recipientId)...No any signal key from server")
            MixinDatabase.shared.insertOrReplace(objects: [ParticipantSession(conversationId: conversationId, userId: recipientId, sessionId: sessionId, sentToServer: SenderKeyStatus.UNKNOWN.rawValue, createdAt: Date().toUTCString())])
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
        let (success, retry) = deliverNoThrow(blazeMessage: blazeMessage)
        if success {
            MixinDatabase.shared.insertOrReplace(objects: [ParticipantSession(conversationId: conversationId, userId: recipientId, sessionId: sessionId, sentToServer: SenderKeyStatus.SENT.rawValue, createdAt: Date().toUTCString())])
        } else if retry {
            return try sendSenderKey(conversationId: conversationId, recipientId: recipientId, sessionId: sessionId)
        }
        Logger.write(conversationId: conversationId, log: "[DeliverSenderKey]...messageId:\(blazeMessage.params?.messageId ?? "")...sessionId:\(sessionId)...recipientId:\(recipientId)...\(success)")
        return success
    }

    func sendNoKeyMessage(conversationId: String, recipientId: String) {
        let plainData = PlainJsonMessagePayload(action: PlainDataAction.NO_KEY.rawValue, messageId: nil, messages: nil, ackMessages: nil)
        let encoded = (try? JSONEncoder.default.encode(plainData))?.base64EncodedString() ?? ""
        let params = BlazeMessageParam(conversationId: conversationId, recipientId: recipientId, category: MessageCategory.PLAIN_JSON.rawValue, data: encoded, status: MessageStatus.SENDING.rawValue, messageId: UUID().uuidString.lowercased())
        let blazeMessage = BlazeMessage(params: params, action: BlazeMessageAction.createMessage.rawValue)
        SendMessageService.shared.sendMessage(conversationId: conversationId, userId: recipientId, blazeMessage: blazeMessage, action: .SEND_NO_KEY)
    }

    func refreshParticipantSession(conversationId: String, userId: String, retry: Bool) -> Bool {
        Logger.write(conversationId: conversationId, log: "[RefreshSession]...userId:\(userId)...retry:\(retry)")
        repeat {
            guard LoginManager.shared.isLoggedIn else {
                return false
            }

            switch UserSessionAPI.shared.fetchSessions(userIds: [userId]) {
            case let .success(sessions):
                let participantSessions = sessions.map {
                    ParticipantSession(conversationId: conversationId, userId: $0.userId, sessionId: $0.sessionId, sentToServer: nil, createdAt: Date().toUTCString())
                }
                MixinDatabase.shared.insertOrReplace(objects: participantSessions)
                return true
            case let .failure(error):
                guard retry else {
                    return false
                }
                guard error.code != 401 else {
                    return false
                }
                checkNetworkAndWebSocket()
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
            } catch {
                if let err = error as? APIError {
                    if err.code == 401 {
                        return nil
                    } else if err.code == 403 {
                        return nil
                    }
                }

                checkNetworkAndWebSocket()

                Thread.sleep(forTimeInterval: 2)
            }
        } while true
    }

    @discardableResult
    internal func deliverNoThrow(blazeMessage: BlazeMessage) -> (success: Bool, retry: Bool) {
        repeat {
            do {
                return (try WebSocketService.shared.respondedMessage(for: blazeMessage).success, false)
            } catch {
                if let err = error as? APIError {
                    if err.code == 403 {
                        return (true, false)
                    } else if err.code == 401 {
                        return (false, false)
                    } else if err.code == 20140 {
                        if let conversationId = blazeMessage.params?.conversationId {
                            syncConversation(conversationId: conversationId)
                        }
                        return (false, true)
                    }
                }
                checkNetworkAndWebSocket()
                Thread.sleep(forTimeInterval: 2)
            }
        } while true
    }

    @discardableResult
    internal func deliver(blazeMessage: BlazeMessage) throws -> Bool {
        var blazeMessage = blazeMessage
        if let conversationId = blazeMessage.params?.conversationId {
            let checksum = ConversationChecksumCalculator.checksum(conversationId: conversationId)
            blazeMessage.params?.conversationChecksum = checksum
        }
        repeat {
            guard LoginManager.shared.isLoggedIn else {
                return false
            }
            
            do {
                return try WebSocketService.shared.respondedMessage(for: blazeMessage).success
            } catch {
                #if DEBUG
                print("======SendMessaegService...deliver...error:\(error)")
                #endif

                guard let err = error as? APIError else {
                    reporter.report(error: error)
                    Thread.sleep(forTimeInterval: 2)
                    return false
                }

                if err.code == 403 {
                    return true
                } else if err.code == 401 {
                    return false
                } else if err.code == 20140 {
                    if let conversationId = blazeMessage.params?.conversationId {
                        syncConversation(conversationId: conversationId)
                    }
                    throw error
                }

                checkNetworkAndWebSocket()

                if err.isClientError {
                    continue
                }
                throw error
            }
        } while true
    }

    internal func checkNetworkAndWebSocket() {
        repeat {
            Thread.sleep(forTimeInterval: 2)
        } while LoginManager.shared.isLoggedIn && !MixinService.isStopProcessMessages && (!NetworkManager.shared.isReachable || !WebSocketService.shared.isConnected)
    }

    internal func checkNetwork() {
        repeat {
            Thread.sleep(forTimeInterval: 2)
        } while LoginManager.shared.isLoggedIn && !MixinService.isStopProcessMessages && !NetworkManager.shared.isReachable
    }
    
    public func stopRecallMessage(messageId: String, category: String, conversationId: String, mediaUrl: String?) {
        UNUserNotificationCenter.current().removeNotifications(withIdentifiers: [messageId])
        
        let userInfo = [SendMessageService.UserInfoKey.conversationId: conversationId,
                        SendMessageService.UserInfoKey.messageId: messageId]
        DispatchQueue.main.sync {
            NotificationCenter.default.post(name: SendMessageService.willRecallMessageNotification, object: self, userInfo: userInfo)
        }
        
        ConcurrentJobQueue.shared.cancelJob(jobId: AttachmentDownloadJob.jobId(category: category, messageId: messageId))

        if let mediaUrl = mediaUrl {
            AttachmentContainer.removeMediaFiles(mediaUrl: mediaUrl, category: category)
        }
    }
    
}
