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
                let sentSenderKeys = noKeyList.compactMap { ParticipantSession(conversationId: conversationId, userId: $0.userId, sessionId: $0.sessionId!, sentToServer: SentToServerStatus.UNKNOWN.rawValue, createdAt: Date().toUTCString()) }
                MixinDatabase.shared.insertOrReplace(objects: sentSenderKeys)
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
            let sentSenderKeys = signalKeyMessages.compactMap { ParticipantSession(conversationId: conversationId, userId: $0.recipientId!, sessionId: $0.sessionId!, sentToServer: SentToServerStatus.SENT.rawValue, createdAt: Date().toUTCString()) }
            MixinDatabase.shared.insertOrReplace(objects: sentSenderKeys)
        }
        FileManager.default.writeLog(conversationId: conversationId, log: "[SendBatchSenderKey][CREATE_SIGNAL_KEY_MESSAGES]...deliver:\(result)...\(signalKeyMessages.map { "{\($0.messageId):\($0.recipientId ?? "")}" }.joined(separator: ","))...")
        FileManager.default.writeLog(conversationId: conversationId, log: "[SendBatchSenderKey][SignalKeys]...\(signalKeys.map { "{\($0.userId ?? "")}" }.joined(separator: ","))...")
    }

    internal func checkSessionSync(conversationId: String) {
        let conversations = SessionSyncDAO.shared.getSyncSessions(conversationId: conversationId)
        guard conversations.count > 0 else {
            return
        }
        sendSessionSyncMessage(conversations: conversations)
    }

    internal func checkSignalSession(recipientId: String, sessionId: String? = nil) throws -> Bool {
        let deviceId = sessionId?.hashCode() ?? SignalProtocol.shared.DEFAULT_DEVICE_ID
        if !SignalProtocol.shared.containsSession(recipient: recipientId, deviceId: deviceId) {
            let signalKeys = signalKeysChannel(requestSignalKeyUsers: [BlazeMessageParamSession(userId: recipientId, sessionId: sessionId)])
            guard signalKeys.count > 0 else {
                FileManager.default.writeLog(log: "[MixinService][CheckSignalSession]...recipientId:\(recipientId)...sessionId:\(sessionId ?? "")...signal keys count is zero ")
                return false
            }
            try SignalProtocol.shared.processSession(userId: recipientId, key: signalKeys[0], deviceId: deviceId)
        }
        return true
    }

    internal func sendSessionSyncMessage(conversations: [SessionSync]) {
        guard conversations.count > 0 else {
            return
        }
        
        let conversationIds = conversations.map { $0.conversationId }

        let params = BlazeMessageParam(conversations: conversationIds)
        let blazeMessage = BlazeMessage(params: params, action: BlazeMessageAction.createSessionSyncMessages.rawValue)
        let result = deliverNoThrow(blazeMessage: blazeMessage)
        if result {
            SessionSyncDAO.shared.removeSyncSessions(conversationIds: conversationIds)
        }
    }

    @discardableResult
    internal func sendSenderKey(conversationId: String, recipientId: String, sessionId: String? = nil, isForce: Bool = false) throws -> Bool {
        if (!SignalProtocol.shared.containsSession(recipient: recipientId, deviceId: SignalProtocol.convertSessionIdToDeviceId(sessionId))) || isForce {
            let signalKeys = signalKeysChannel(requestSignalKeyUsers: [BlazeMessageParamSession(userId: recipientId, sessionId: sessionId)])
            if signalKeys.count > 0 {
                try SignalProtocol.shared.processSession(userId: recipientId, key: signalKeys[0], deviceId: SignalProtocol.convertSessionIdToDeviceId(sessionId))
            } else {
                FileManager.default.writeLog(conversationId: conversationId, log: "[SendSenderKey]...recipientId:\(recipientId)...No any signal key from server")
                if let sessionId = sessionId, !sessionId.isEmpty {
                    ParticipantSessionDAO.shared.insertParticipentSession(participantSession: ParticipantSession(conversationId: conversationId, userId: recipientId, sessionId: sessionId, sentToServer: SentToServerStatus.UNKNOWN.rawValue, createdAt: Date().toUTCString()))
                }
                return false
            }
        }

        let (cipherText, isError) = try SignalProtocol.shared.encryptSenderKey(conversationId: conversationId, recipientId: recipientId, sessionId: sessionId)
        guard !isError else {
            return false
        }
        let blazeMessage = try BlazeMessage(conversationId: conversationId, recipientId: recipientId, cipherText: cipherText, sessionId: sessionId)
        let result = deliverNoThrow(blazeMessage: blazeMessage)
        if result {
            if let sessionId = sessionId, !sessionId.isEmpty {
                ParticipantSessionDAO.shared.insertParticipentSession(participantSession: ParticipantSession(conversationId: conversationId, userId: recipientId, sessionId: sessionId, sentToServer: SentToServerStatus.SENT.rawValue, createdAt: Date().toUTCString()))
            }
        }
        FileManager.default.writeLog(conversationId: conversationId, log: "[DeliverSenderKey]...messageId:\(blazeMessage.params?.messageId ?? "")...sessionId:\(sessionId ?? "")...recipientId:\(recipientId)...\(result)")
        return result
    }

    internal func resendSenderKey(conversationId: String, recipientId: String, sessionId: String?) throws {
        let result = try sendSenderKey(conversationId: conversationId, recipientId: recipientId, sessionId: sessionId, isForce: true)
        if !result {
            sendNoKeyMessage(conversationId: conversationId, recipientId: recipientId)
        }
    }

    private func sendNoKeyMessage(conversationId: String, recipientId: String) {
        let plainData = TransferPlainData(action: PlainDataAction.NO_KEY.rawValue, messageId: nil, messages: nil, status: nil)
        let encoded = (try? jsonEncoder.encode(plainData))?.base64EncodedString() ?? ""
        let params = BlazeMessageParam(conversationId: conversationId, recipientId: recipientId, category: MessageCategory.PLAIN_JSON.rawValue, data: encoded, status: MessageStatus.SENDING.rawValue, messageId: UUID().uuidString.lowercased())
        let blazeMessage = BlazeMessage(params: params, action: BlazeMessageAction.createMessage.rawValue)
        SendMessageService.shared.sendMessage(conversationId: conversationId, userId: recipientId, blazeMessage: blazeMessage, action: .SEND_NO_KEY)
    }

    private func signalKeysChannel(requestSignalKeyUsers: [BlazeMessageParamSession]) -> [SignalKey] {
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
