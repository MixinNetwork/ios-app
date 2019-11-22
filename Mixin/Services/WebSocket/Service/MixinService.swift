import Foundation
import UserNotifications

class MixinService {

    var processing = false
    let jsonDecoder = JSONDecoder()
    let jsonEncoder = JSONEncoder()

    internal var currentAccountId: String {
        return AccountAPI.shared.accountUserId
    }

    internal func checkSessionSenderKey(conversationId: String) throws {
        let participants = ParticipantSessionDAO.shared.getNotSendSessionParticipants(conversationId: conversationId, sessionId: AccountAPI.shared.accountSessionId)
        guard participants.count > 0 else {
            return
        }

        var requestSignalKeyUsers = [BlazeMessageParamSession]()
        var signalKeyMessages = [TransferMessage]()
        for p in participants {
            if SignalProtocol.shared.containsSession(recipient: p.userId, deviceId: SignalProtocol.convertSessionIdToDeviceId(p.sessionId)) {
                FileManager.default.writeLog(conversationId: conversationId, log: "[CheckSessionSenderKey]...containsSession...\(p.userId)")
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
        var signalKeys = [SignalKey]()

        if !requestSignalKeyUsers.isEmpty {
            signalKeys = signalKeysChannel(requestSignalKeyUsers: requestSignalKeyUsers)
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
        }
        
        guard signalKeyMessages.count > 0 else {
            return
        }
        let checksum = getCheckSum(conversationId: conversationId)
        let param = BlazeMessageParam(conversationId: conversationId, messages: signalKeyMessages, checksum: checksum)
        let blazeMessage = BlazeMessage(params: param, action: BlazeMessageAction.createSignalKeyMessage.rawValue)
        let (success, retry) = deliverNoThrow(blazeMessage: blazeMessage)
        if success {
            let sentSenderKeys = signalKeyMessages.compactMap { ParticipantSession(conversationId: conversationId, userId: $0.recipientId!, sessionId: $0.sessionId!, sentToServer: SenderKeyStatus.SENT.rawValue, createdAt: Date().toUTCString()) }
            MixinDatabase.shared.insertOrReplace(objects: sentSenderKeys)
        } else if retry {
            return try checkSessionSenderKey(conversationId: conversationId)
        }

        FileManager.default.writeLog(conversationId: conversationId, log: "[CheckSessionSenderKey][CREATE_SIGNAL_KEY_MESSAGES]...deliver:\(success)...retry:\(retry)...\(signalKeyMessages.map { "{\($0.messageId):\($0.recipientId ?? "")}" }.joined(separator: ","))...")
        FileManager.default.writeLog(conversationId: conversationId, log: "[CheckSessionSenderKey][SignalKeys]...\(signalKeys.map { "{\($0.userId ?? "")}" }.joined(separator: ","))...")
    }

    internal func syncConversation(conversationId: String) {
        repeat {
            switch ConversationAPI.shared.getConversation(conversationId: conversationId) {
            case let .success(response):
                ParticipantSessionDAO.shared.syncConversationParticipantSession(conversation: response)
                return
            case let .failure(error):
                if error.code == 401 {
                    return
                }
                checkNetworkAndWebSocket()
            }
        } while true
    }

    private func getCheckSum(conversationId: String) -> String {
        let sessions = ParticipantSessionDAO.shared.getParticipantSessions(conversationId: conversationId)
        return sessions.count == 0 ? "" : generateConversationChecksum(sessions: sessions)
    }

    private func generateConversationChecksum(sessions: [ParticipantSession]) -> String {
        return sessions.map { $0.sessionId }.sorted().joined().md5()
    }

    internal func checkSignalSession(recipientId: String, sessionId: String? = nil) throws -> Bool {
        let deviceId = SignalProtocol.convertSessionIdToDeviceId(sessionId)
        if !SignalProtocol.shared.containsSession(recipient: recipientId, deviceId: deviceId) {
            let signalKeys = signalKeysChannel(requestSignalKeyUsers: [BlazeMessageParamSession(userId: recipientId, sessionId: sessionId)])
            guard signalKeys.count > 0 else {
                FileManager.default.writeLog(log: "[MixinService][CheckSignalSession]...recipientId:\(recipientId)...sessionId:\(sessionId ?? "")...signal keys count is zero ")
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
            FileManager.default.writeLog(conversationId: conversationId, log: "[SendSenderKey]...recipientId:\(recipientId)...No any signal key from server")
            MixinDatabase.shared.insertOrReplace(objects: [ParticipantSession(conversationId: conversationId, userId: recipientId, sessionId: sessionId, sentToServer: SenderKeyStatus.UNKNOWN.rawValue, createdAt: Date().toUTCString())])
            return false
        }

        let (cipherText, isError) = try SignalProtocol.shared.encryptSenderKey(conversationId: conversationId, recipientId: recipientId, sessionId: sessionId)
        guard !isError else {
            return false
        }
        let signalKeyMessages = [TransferMessage(recipientId: recipientId, data: cipherText, sessionId: sessionId)]
        let checksum = getCheckSum(conversationId: conversationId)
        let param = BlazeMessageParam(conversationId: conversationId, messages: signalKeyMessages, checksum: checksum)
        let blazeMessage = BlazeMessage(params: param, action: BlazeMessageAction.createSignalKeyMessage.rawValue)
        let (success, retry) = deliverNoThrow(blazeMessage: blazeMessage)
        if success {
            MixinDatabase.shared.insertOrReplace(objects: [ParticipantSession(conversationId: conversationId, userId: recipientId, sessionId: sessionId, sentToServer: SenderKeyStatus.SENT.rawValue, createdAt: Date().toUTCString())])
        } else if retry {
            return try sendSenderKey(conversationId: conversationId, recipientId: recipientId, sessionId: sessionId)
        }
        FileManager.default.writeLog(conversationId: conversationId, log: "[DeliverSenderKey]...messageId:\(blazeMessage.params?.messageId ?? "")...sessionId:\(sessionId)...recipientId:\(recipientId)...\(success)")
        return success
    }

    func sendNoKeyMessage(conversationId: String, recipientId: String) {
        let plainData = PlainJsonMessagePayload(action: PlainDataAction.NO_KEY.rawValue, messageId: nil, messages: nil, ackMessages: nil)
        let encoded = (try? jsonEncoder.encode(plainData))?.base64EncodedString() ?? ""
        let params = BlazeMessageParam(conversationId: conversationId, recipientId: recipientId, category: MessageCategory.PLAIN_JSON.rawValue, data: encoded, status: MessageStatus.SENDING.rawValue, messageId: UUID().uuidString.lowercased())
        let blazeMessage = BlazeMessage(params: params, action: BlazeMessageAction.createMessage.rawValue)
        SendMessageService.shared.sendMessage(conversationId: conversationId, userId: recipientId, blazeMessage: blazeMessage, action: .SEND_NO_KEY)
    }

    func refreshParticipantSession(conversationId: String, userId: String, retry: Bool) -> Bool {
        FileManager.default.writeLog(conversationId: conversationId, log: "[RefreshSession]...userId:\(userId)...retry:\(retry)")
        repeat {
            guard AccountAPI.shared.didLogin else {
                return false
            }

            switch UserAPI.shared.fetchSessions(userIds: [userId]) {
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
                return try WebSocketService.shared.respondedMessage(for: blazeMessage)
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
                return (try WebSocketService.shared.respondedMessage(for: blazeMessage) != nil, false)
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
            blazeMessage.params?.conversationChecksum = getCheckSum(conversationId: conversationId)
        }
        repeat {
            guard AccountAPI.shared.didLogin else {
                return false
            }
            
            do {
                return try WebSocketService.shared.respondedMessage(for: blazeMessage) != nil
            } catch {
                #if DEBUG
                print("======SendMessaegService...deliver...error:\(error)")
                #endif

                guard let err = error as? APIError else {
                    Reporter.report(error: error)
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
                    Thread.sleep(forTimeInterval: 2)
                    continue
                }
                throw error
            }
        } while true
    }

    internal func checkNetworkAndWebSocket() {
        while AccountAPI.shared.didLogin && (!NetworkManager.shared.isReachable || !WebSocketService.shared.isConnected) {
            Thread.sleep(forTimeInterval: 2)
        }

        Thread.sleep(forTimeInterval: 2)
    }

    func stopRecallMessage(messageId: String, category: String, conversationId: String, mediaUrl: String?) {
        UNUserNotificationCenter.current().removeNotifications(identifier: messageId)

        DispatchQueue.main.sync {
            if let chatVC = UIApplication.homeNavigationController?.viewControllers.last as? ConversationViewController, conversationId == chatVC.dataSource?.conversationId {
                chatVC.handleMessageRecalling(messageId: messageId)
            }
            if let gallery = UIApplication.homeContainerViewController?.galleryViewController {
                gallery.handleMessageRecalling(messageId: messageId)
            }
        }

        if messageId == AudioManager.shared.playingMessage?.messageId {
            AudioManager.shared.stop()
        }

        ConcurrentJobQueue.shared.cancelJob(jobId: AttachmentDownloadJob.jobId(category: category, messageId: messageId))

        if let attachmentCategory = AttachmentContainer.Category(messageCategory: category), let mediaUrl = mediaUrl {
            try? FileManager.default.removeItem(at: AttachmentContainer.url(for: attachmentCategory, filename: mediaUrl))
            if category.hasSuffix("_VIDEO") {
                let thumbUrl = AttachmentContainer.url(for: .videos, filename: mediaUrl.substring(endChar: ".") + ExtensionName.jpeg.withDot)
                try? FileManager.default.removeItem(at: thumbUrl)
            }
        }


    }

}
