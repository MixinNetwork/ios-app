import Foundation
import UserNotifications

class MixinService {

    var processing = false
    let jsonDecoder = JSONDecoder()
    let jsonEncoder = JSONEncoder()

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
                let cipherText = try SignalProtocol.shared.encryptSenderKey(conversationId: conversationId, recipientId: p.userId)
                signalKeyMessages.append(TransferMessage(recipientId: p.userId, data: cipherText))
            } else {
                requestSignalKeyUsers.append(BlazeSessionMessageParam(userId: p.userId, sessionId: nil))
            }
        }

        var noKeyList = [BlazeSessionMessageParam]()
        var signalKeys = [SignalKeyResponse]()

        if !requestSignalKeyUsers.isEmpty {
            signalKeys = signalKeysChannel(requestSignalKeyUsers: requestSignalKeyUsers)
            var keys = [String]()
            for signalKey in signalKeys {
                guard let recipientId = signalKey.userId else {
                    continue
                }
                try SignalProtocol.shared.processSession(userId: recipientId, signalKey: signalKey)
                let cipherText = try SignalProtocol.shared.encryptSenderKey(conversationId: conversationId, recipientId: recipientId)
                signalKeyMessages.append(TransferMessage(recipientId: recipientId, data: cipherText))
                keys.append(recipientId)
            }

            noKeyList = requestSignalKeyUsers.filter{!keys.contains($0.userId)}
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
        FileManager.default.writeLog(conversationId: conversationId, log: "[SendBatchSenderKey][CREATE_SIGNAL_KEY_MESSAGES]...deliver:\(result)...\(signalKeyMessages.map { "{\($0.messageId):\($0.recipientId ?? "")}" }.joined(separator: ","))...")
        FileManager.default.writeLog(conversationId: conversationId, log: "[SendBatchSenderKey][SignalKeys]...\(signalKeys.map { "{\($0.userId ?? "")}" }.joined(separator: ","))...")
    }

    internal func checkSignalSession(recipientId: String, sessionId: String? = nil) throws -> Bool {
        let deviceId = sessionId?.hashCode() ?? SignalProtocol.shared.DEFAULT_DEVICE_ID
        if !SignalProtocol.shared.containsSession(recipient: recipientId, deviceId: deviceId) {
            let signalKeys = signalKeysChannel(requestSignalKeyUsers: [BlazeSessionMessageParam(userId: recipientId, sessionId: sessionId)])
            guard signalKeys.count > 0 else {
                FileManager.default.writeLog(log: "[MixinService][CheckSignalSession]...recipientId:\(recipientId)...sessionId:\(sessionId ?? "")...signal keys count is zero ")
                return false
            }
            try SignalProtocol.shared.processSession(userId: recipientId, signalKey: signalKeys[0], deviceId: deviceId)
        }
        return true
    }

    @discardableResult
    internal func resendSenderKey(conversationId: String, recipientId: String) throws -> Bool {
        let signalKeys = signalKeysChannel(requestSignalKeyUsers: [BlazeSessionMessageParam(userId: recipientId, sessionId: nil)])
        guard signalKeys.count > 0 else {
            SentSenderKeyDAO.shared.replace(SentSenderKey(conversationId: conversationId, userId: recipientId, sentToServer: SentSenderKeyStatus.UNKNOWN.rawValue))
            FileManager.default.writeLog(conversationId: conversationId, log: "[ResendSenderKey]...recipientId:\(recipientId)...No any group signal key from server")
            sendNoKeyMessage(conversationId: conversationId, recipientId: recipientId)
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
        let plainData = TransferPlainData(action: PlainDataAction.NO_KEY.rawValue, messageId: nil, messages: nil, status: nil)
        let encoded = (try? jsonEncoder.encode(plainData))?.base64EncodedString() ?? ""
        let params = BlazeMessageParam(conversationId: conversationId, recipientId: recipientId, category: MessageCategory.PLAIN_JSON.rawValue, data: encoded, status: MessageStatus.SENDING.rawValue, messageId: UUID().uuidString.lowercased())
        let blazeMessage = BlazeMessage(params: params, action: BlazeMessageAction.createMessage.rawValue)
        SendMessageService.shared.sendMessage(conversationId: conversationId, userId: recipientId, blazeMessage: blazeMessage, action: .SEND_NO_KEY)
    }

    private func deliverSenderKey(conversationId: String, recipientId: String) throws -> Bool {
        let cipherText = try SignalProtocol.shared.encryptSenderKey(conversationId: conversationId, recipientId: recipientId)
        let blazeMessage = try BlazeMessage(conversationId: conversationId, recipientId: recipientId, cipherText: cipherText)
        let result = deliverNoThrow(blazeMessage: blazeMessage)
        if result {
            SentSenderKeyDAO.shared.replace(SentSenderKey(conversationId: conversationId, userId: recipientId, sentToServer: SentSenderKeyStatus.SENT.rawValue))
        }
        FileManager.default.writeLog(conversationId: conversationId, log: "[DeliverSenderKey]...messageId:\(blazeMessage.params?.messageId ?? "")...recipientId:\(recipientId)...\(result)")
        return result
    }

    private func signalKeysChannel(requestSignalKeyUsers: [BlazeSessionMessageParam]) -> [SignalKeyResponse] {
        let blazeMessage = BlazeMessage(params: BlazeMessageParam(consumeSignalKeys: requestSignalKeyUsers), action: BlazeMessageAction.consumeSessionSignalKeys.rawValue)
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
            guard AccountAPI.shared.didLogin else {
                return false
            }
            
            do {
                return try WebSocketService.shared.syncSendMessage(blazeMessage: blazeMessage) != nil
            } catch {
                #if DEBUG
                print("======SendMessaegService...deliver...error:\(error)")
                #endif

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

        if let chatDirectory = MixinFile.ChatDirectory.getDirectory(category: category), let mediaUrl = mediaUrl {
            try? FileManager.default.removeItem(at: MixinFile.url(ofChatDirectory: chatDirectory, filename: mediaUrl))

            if category.hasSuffix("_VIDEO") {
                let thumbUrl = MixinFile.url(ofChatDirectory: .videos, filename: mediaUrl.substring(endChar: ".") + ExtensionName.jpeg.withDot)
                try? FileManager.default.removeItem(at: thumbUrl)
            }
        }


    }

}
