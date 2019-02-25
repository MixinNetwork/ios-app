import Foundation

class MixinService {

    internal(set) var processing = false
    internal let jsonDecoder = JSONDecoder()
    internal let jsonEncoder = JSONEncoder()

    internal var currentAccountId: String {
        return AccountAPI.shared.accountUserId
    }

    internal func sendGroupSenderKey(conversationId: String) throws {
        let participants = ParticipantDAO.shared.getNotAppParticipants(conversationId: conversationId, accountId: currentAccountId)
        guard participants.count > 0 else {
            return
        }
        try sendBatchSenderKey(conversationId: conversationId, participants: participants, from: "sendGroupSenderKey")
    }

    internal func sendBatchSenderKey(conversationId: String, participants: [Participant], from: String) throws {
        var requestSignalKeyUsers = [BlazeSessionMessageParam]()
        var signalKeyMessages = [TransferMessage]()
        for p in participants {
            if SignalProtocol.shared.containsSession(recipient: p.userId) {
                FileManager.default.writeLog(conversationId: conversationId, log: "[SendGroupSenderKey]...containsSession...\(p.userId)")
                let cipherText = try SignalProtocol.shared.encryptSenderKey(conversationId: conversationId, senderId: currentAccountId, recipientId: p.userId)
                signalKeyMessages.append(TransferMessage(recipientId: p.userId, data: cipherText))
            } else {
                requestSignalKeyUsers.append(BlazeSessionMessageParam(userId: p.userId, sessionId: nil))
            }
        }

        var noKeyList = [String]()
        var signalKeys = [SignalKeyResponse]()

        if !requestSignalKeyUsers.isEmpty {
            signalKeys = signalKeysChannel(requestSignalKeyUsers: requestSignalKeyUsers)
            var keys = [String]()
            for signalKey in signalKeys {
                guard let recipientId = signalKey.userId else {
                    continue
                }
                try SignalProtocol.shared.processSession(userId: recipientId, signalKey: signalKey)
                let cipherText = try SignalProtocol.shared.encryptSenderKey(conversationId: conversationId, senderId: AccountAPI.shared.accountUserId, recipientId: recipientId)
                signalKeyMessages.append(TransferMessage(recipientId: recipientId, data: cipherText))
                keys.append(recipientId)
            }

            noKeyList = requestSignalKeyUsers.filter{!keys.contains($0.userId)}.compactMap{ $0.userId }
            if !noKeyList.isEmpty {
                SentSenderKeyDAO.shared.batchInsert(conversationId: conversationId, messages: noKeyList,  status: SentSenderKeyStatus.UNKNOWN.rawValue)
            }
        }

        FileManager.default.writeLog(conversationId: conversationId, log: "[SendBatchSenderKey]...signalKeyMessages:\(signalKeyMessages.count) + noKeyList:\(noKeyList.count)...requestSignalKeyUsers:\(requestSignalKeyUsers.count)...signalKeys:\(signalKeys.count)")

        guard signalKeyMessages.count > 0 else {
            return
        }
        let param = BlazeMessageParam(conversationId: conversationId, messages: signalKeyMessages)
        let blazeMessage = BlazeMessage(params: param, action: BlazeMessageAction.createSignalKeyMessage.rawValue)
        let result = deliverNoThrow(blazeMessage: blazeMessage)
        if result {
            SentSenderKeyDAO.shared.batchUpdate(conversationId: conversationId, messages: signalKeyMessages)
        }
        FileManager.default.writeLog(conversationId: conversationId, log: "[SendBatchSenderKey][CREATE_SIGNAL_KEY_MESSAGES]...deliver:\(result)...\(signalKeyMessages.map { "{\($0.messageId):\($0.recipientId)}" }.joined(separator: ","))...")
        FileManager.default.writeLog(conversationId: conversationId, log: "[SendBatchSenderKey][SignalKeys]...\(signalKeys.map { "{\($0.userId ?? "")}" }.joined(separator: ","))...")
    }

    internal func checkSignalSession(recipientId: String, sessionId: String? = nil) throws -> Bool {
        let deviceId = sessionId?.hashCode() ?? SignalProtocol.shared.DEFAULT_DEVICE_ID
        if !SignalProtocol.shared.containsSession(recipient: recipientId, deviceId: deviceId) {
            let signalKeys = signalKeysChannel(requestSignalKeyUsers: [BlazeSessionMessageParam(userId: recipientId, sessionId: sessionId)])
            guard signalKeys.count > 0 else {
                return false
            }
            try SignalProtocol.shared.processSession(userId: recipientId, signalKey: signalKeys[0], deviceId: deviceId)
        }
        return true
    }

    @discardableResult
    internal func resendSenderKey(conversationId: String, recipientId: String, resendKey: Bool = false) throws -> Bool {
        let signalKeys = signalKeysChannel(requestSignalKeyUsers: [BlazeSessionMessageParam(userId: recipientId, sessionId: nil)])
        guard signalKeys.count > 0 else {
            SentSenderKeyDAO.shared.replace(SentSenderKey(conversationId: conversationId, userId: recipientId, sentToServer: SentSenderKeyStatus.UNKNOWN.rawValue))
            FileManager.default.writeLog(conversationId: conversationId, log: "[ResendSenderKey]...recipientId:\(recipientId)...No any group signal key from server")
            if resendKey {
                sendNoKeyMessage(conversationId: conversationId, recipientId: recipientId)
            }
            return false
        }
        try SignalProtocol.shared.processSession(userId: recipientId, signalKey: signalKeys[0])
        return try deliverSenderKey(conversationId: conversationId, recipientId: recipientId)
    }

    @discardableResult
    internal func sendSenderKey(conversationId: String, recipientId: String, resendKey: Bool = false) throws -> Bool {
        if !SignalProtocol.shared.containsSession(recipient: recipientId) {
            let signalKeys = signalKeysChannel(requestSignalKeyUsers: [BlazeSessionMessageParam(userId: recipientId, sessionId: nil)])
            guard signalKeys.count > 0 else {
                SentSenderKeyDAO.shared.replace(SentSenderKey(conversationId: conversationId, userId: recipientId, sentToServer: SentSenderKeyStatus.UNKNOWN.rawValue))
                FileManager.default.writeLog(conversationId: conversationId, log: "[SendSenderKey]...recipientId:\(recipientId)...No any group signal key from server")
                if resendKey {
                    sendNoKeyMessage(conversationId: conversationId, recipientId: recipientId)
                }
                return false
            }
            try SignalProtocol.shared.processSession(userId: recipientId, signalKey: signalKeys[0])
        }
        return try deliverSenderKey(conversationId: conversationId, recipientId: recipientId)
    }

    private func sendNoKeyMessage(conversationId: String, recipientId: String) {
        guard !JobDAO.shared.isExist(conversationId: conversationId, userId: recipientId, action: .SEND_NO_KEY) else {
            return
        }
        let plainData = TransferPlainData(action: PlainDataAction.NO_KEY.rawValue, messageId: nil, messages: nil, status: nil)
        let encoded = (try? jsonEncoder.encode(plainData))?.base64EncodedString() ?? ""
        let params = BlazeMessageParam(conversationId: conversationId, recipientId: recipientId, category: MessageCategory.PLAIN_JSON.rawValue, data: encoded, offset: nil, status: MessageStatus.SENDING.rawValue, messageId: UUID().uuidString.lowercased(), quoteMessageId: nil, keys: nil, recipients: nil, messages: nil, sessionId: nil, transferId: nil)
        let blazeMessage = BlazeMessage(params: params, action: BlazeMessageAction.createMessage.rawValue)
        SendMessageService.shared.sendMessage(conversationId: conversationId, userId: recipientId, blazeMessage: blazeMessage, action: .SEND_NO_KEY)
    }

    private func deliverSenderKey(conversationId: String, recipientId: String) throws -> Bool {
        let cipherText = try SignalProtocol.shared.encryptSenderKey(conversationId: conversationId, senderId: AccountAPI.shared.accountUserId, recipientId: recipientId)
        let blazeMessage = try BlazeMessage(conversationId: conversationId, recipientId: recipientId, cipherText: cipherText)
        let result = deliverNoThrow(blazeMessage: blazeMessage)
        if result {
            SentSenderKeyDAO.shared.replace(SentSenderKey(conversationId: conversationId, userId: recipientId, sentToServer: SentSenderKeyStatus.SENT.rawValue))
        }
        FileManager.default.writeLog(conversationId: conversationId, log: "[DeliverSenderKey]...recipientId:\(recipientId)...\(result)")
        return result
    }

    private func signalKeysChannel(requestSignalKeyUsers: [BlazeSessionMessageParam]) -> [SignalKeyResponse] {
        let blazeMessage = BlazeMessage(params: BlazeMessageParam(consumeSignalKeys: requestSignalKeyUsers), action: BlazeMessageAction.consumeSignalKeys.rawValue)
        return deliverKeys(blazeMessage: blazeMessage)?.toConsumeSignalKeys() ?? []
    }

    @discardableResult
    internal func deliverKeys(blazeMessage: BlazeMessage) -> BlazeMessage? {
        repeat {
            do {
                return try WebSocketService.shared.syncSendMessage(blazeMessage: blazeMessage)
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
    internal func deliverNoThrow(blazeMessage: BlazeMessage) -> Bool {
        repeat {
            do {
                return try WebSocketService.shared.syncSendMessage(blazeMessage: blazeMessage) != nil
            } catch {
                if let err = error as? APIError {
                    if err.code == 403 {
                        return true
                    } else if err.code == 401 {
                        return false
                    }
                }

                checkNetworkAndWebSocket()
                Thread.sleep(forTimeInterval: 2)
            }
        } while true
    }

    @discardableResult
    internal func deliver(blazeMessage: BlazeMessage) throws -> Bool {
        repeat {
            do {
                return try WebSocketService.shared.syncSendMessage(blazeMessage: blazeMessage) != nil
            } catch {
                guard let err = error as? APIError else {
                    Thread.sleep(forTimeInterval: 2)
                    return false
                }

                if err.code == 403 {
                    return true
                } else if err.code == 401 {
                    return false
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
        while AccountAPI.shared.didLogin && (!NetworkManager.shared.isReachable || !WebSocketService.shared.connected) {
            Thread.sleep(forTimeInterval: 2)
        }

        Thread.sleep(forTimeInterval: 2)
    }

}
