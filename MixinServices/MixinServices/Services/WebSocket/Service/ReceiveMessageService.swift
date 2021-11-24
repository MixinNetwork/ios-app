import Foundation
import UIKit
import SDWebImage

public protocol CallMessageCoordinator: AnyObject {
    func shouldSendRtcBlazeMessage(with category: MessageCategory) -> Bool
    func handleIncomingBlazeMessageData(_ data: BlazeMessageData)
}

public class ReceiveMessageService: MixinService {
    
    public static let shared = ReceiveMessageService()
    
    public static let groupConversationParticipantDidChangeNotification = Notification.Name("one.mixin.services.group.participant.did.change")
    public static let senderKeyDidChangeNotification = NSNotification.Name("one.mixin.services.ReceiveMessageService.SenderKeyDidChange")
    public static let progressNotification = NSNotification.Name("one.mixin.services.ReceiveMessageService.progressNotification")
    public static let userSessionDidChangeNotification = NSNotification.Name("one.mixin.services.ReceiveMessageService.userSessionDidChange")
    
    private let processDispatchQueue = DispatchQueue(label: "one.mixin.services.queue.receive.messages")
    private let receiveDispatchQueue = DispatchQueue(label: "one.mixin.services.queue.receive")
    
    let messageDispatchQueue = DispatchQueue(label: "one.mixin.services.queue.messages")
    var refreshRefreshOneTimePreKeys = [String: TimeInterval]()

    private lazy var processOperationQueue = OperationQueue(maxConcurrentOperationCount: 1)
	private var queueObservation : NSKeyValueObservation?

	override init() {
		super.init()
		if isAppExtension {
			queueObservation = processOperationQueue.observe(\.operationCount, options: [.new]) { (queue, change) in
				guard let operationCount = change.newValue else {
					return
				}
				AppGroupUserDefaults.isProcessingMessagesInAppExtension = operationCount > 0
			}
		}
	}

	deinit {
		AppGroupUserDefaults.isProcessingMessagesInAppExtension = false
	}

    public var isProcessingMessagesInAppExtension: Bool {
        return isAppExtension && processOperationQueue.operationCount == 0
    }

    func receiveMessage(blazeMessage: BlazeMessage) {
        receiveDispatchQueue.async {
            guard LoginManager.shared.isLoggedIn, !MixinService.isStopProcessMessages else {
                return
            }
            guard let data = blazeMessage.data?.data(using: .utf8), let blazeMessageData = try? JSONDecoder.default.decode(BlazeMessageData.self, from: data) else {
                return
            }
            let messageId = blazeMessageData.messageId
            let status = blazeMessageData.status

            if blazeMessage.action == BlazeMessageAction.acknowledgeMessageReceipt.rawValue {
                MessageDAO.shared.updateMessageStatus(messageId: messageId, status: status, from: blazeMessage.action)
                AppGroupUserDefaults.Crypto.Offset.status = blazeMessageData.updatedAt.toUTCDate().nanosecond()
            } else if blazeMessage.action == BlazeMessageAction.createMessage.rawValue || blazeMessage.action == BlazeMessageAction.createCall.rawValue || blazeMessage.action == BlazeMessageAction.createKraken.rawValue {
                if blazeMessageData.userId == myUserId && blazeMessageData.category.isEmpty {
                    MessageDAO.shared.updateMessageStatus(messageId: messageId, status: status, from: blazeMessage.action)
                } else {
                    guard BlazeMessageDAO.shared.save(messageId: messageId, conversationId: blazeMessageData.conversationId, data: data, createdAt: blazeMessageData.createdAt) else {
                        return
                    }
                    ReceiveMessageService.shared.processReceiveMessages()
                }
            } else {
                ReceiveMessageService.shared.updateRemoteMessageStatus(messageId: messageId, status: .READ)
            }
        }
    }

    public func processReceiveMessage(messageId: String, conversationId: String?, extensionTimeWillExpire: @escaping () -> Bool, callback: @escaping (MessageItem?) -> Void) {
        let startDate = Date()
        processOperationQueue.addOperation {
            if MessageHistoryDAO.shared.isExist(messageId: messageId) {
                callback(nil)
                return
            }

            repeat {
                if -startDate.timeIntervalSinceNow >= 15 || AppGroupUserDefaults.isRunningInMainApp || extensionTimeWillExpire() {
                    if let conversationId = conversationId {
                        Logger.conversation(id: conversationId).info(category: "AppExtension", message: "Abort message processing for: \(messageId). Elapsed time: \(-startDate.timeIntervalSinceNow)s")
                    }
                    callback(nil)
                    return
                } else if let createdAt = BlazeMessageDAO.shared.getMessageBlaze(messageId: messageId)?.createdAt {
                    repeat {
                        let blazeMessageDatas = BlazeMessageDAO.shared.getBlazeMessageData(createdAt: createdAt, limit: 50)
                        guard blazeMessageDatas.count > 0 else {
                            callback(nil)
                            return
                        }

                        for data in blazeMessageDatas {
                            guard !AppGroupUserDefaults.isRunningInMainApp, !extensionTimeWillExpire() else {
                                callback(nil)
                                return
                            }
                            ReceiveMessageService.shared.processReceiveMessage(data: data)
                            if data.messageId == messageId {
                                callback(MessageDAO.shared.getFullMessage(messageId: messageId))
                                return
                            }
                        }
                    } while true
                } else if let message = MessageDAO.shared.getFullMessage(messageId: messageId) {
                   callback(message)
                   return
                } else {
                    WebSocketService.shared.connectIfNeeded()
                    Thread.sleep(forTimeInterval: 2)
                }
            } while true
        }
    }

    public func processReceiveMessages() {
        guard !isAppExtension else {
            return
        }
        guard !MixinService.isStopProcessMessages else {
            return
        }
        guard !processing else {
            return
        }
        processing = true

        processDispatchQueue.async {
            var displaySyncProcess = false
            defer {
                self.processing = false
                if displaySyncProcess {
                    NotificationCenter.default.post(onMainThread: Self.progressNotification,
                                                    object: self,
                                                    userInfo: [Self.UserInfoKey.progress: 100])
                }
            }

            if AppGroupUserDefaults.isProcessingMessagesInAppExtension {
                repeat {
                    let oldDate = AppGroupUserDefaults.checkStatusTimeInAppExtension

                    Logger.general.error(category: "ReceiveMessageService", message: "Waiting for app extension to process messages, checkStatusTimeInAppExtension: \(oldDate), isStopProcessMessages: \(MixinService.isStopProcessMessages)")

                    DarwinNotificationManager.shared.checkAppExtensionStatus()
                    Thread.sleep(forTimeInterval: 2)

                    if oldDate == AppGroupUserDefaults.checkStatusTimeInAppExtension {
                        AppGroupUserDefaults.isProcessingMessagesInAppExtension = false
                    }
                } while AppGroupUserDefaults.isProcessingMessagesInAppExtension && !MixinService.isStopProcessMessages
            }

            var finishedJobCount = 0

            repeat {
                guard LoginManager.shared.isLoggedIn, !MixinService.isStopProcessMessages else {
                    return
                }
                let blazeMessageDatas = BlazeMessageDAO.shared.getBlazeMessageData(limit: 50)
                guard blazeMessageDatas.count > 0 else {
                    return
                }

                let remainJobCount = BlazeMessageDAO.shared.getCount()
                if remainJobCount + finishedJobCount > 500 {
                    displaySyncProcess = true
                    let progress = blazeMessageDatas.count == 0 ? 100 : Int(Float(finishedJobCount) / Float(remainJobCount + finishedJobCount) * 100)
                    NotificationCenter.default.post(onMainThread: Self.progressNotification,
                                                    object: self,
                                                    userInfo: [Self.UserInfoKey.progress: progress])
                }

                for data in blazeMessageDatas {
                    if MixinService.isStopProcessMessages {
                        return
                    }
                    ReceiveMessageService.shared.processReceiveMessage(data: data)
                }

                finishedJobCount += blazeMessageDatas.count
            } while true
        }
    }

    private func processReceiveMessage(data: BlazeMessageData) {
        guard LoginManager.shared.isLoggedIn else {
            return
        }

        if MessageDAO.shared.isExist(messageId: data.messageId) || MessageHistoryDAO.shared.isExist(messageId: data.messageId) {
            ReceiveMessageService.shared.processBadMessage(data: data)
            return
        }

        if data.category != MessageCategory.SYSTEM_USER.rawValue && data.category != MessageCategory.SYSTEM_CONVERSATION.rawValue {
            ReceiveMessageService.shared.syncConversation(data: data)
        }
        ReceiveMessageService.shared.checkSession(data: data)

        if MixinService.isStopProcessMessages {
            return
        }

        if MessageCategory.isLegal(category: data.category) {
            ReceiveMessageService.shared.processSystemMessage(data: data)
            ReceiveMessageService.shared.processPlainMessage(data: data)
            ReceiveMessageService.shared.processSignalMessage(data: data)
            ReceiveMessageService.shared.processEncryptedMessage(data: data)
            ReceiveMessageService.shared.processAppButton(data: data)
            ReceiveMessageService.shared.processAppCard(data: data)
            ReceiveMessageService.shared.processCallMessage(data: data)
            ReceiveMessageService.shared.processRecallMessage(data: data)
            ReceiveMessageService.shared.processPinMessage(data: data)
        } else {
            ReceiveMessageService.shared.processUnknownMessage(data: data)
            ReceiveMessageService.shared.updateRemoteMessageStatus(messageId: data.messageId, status: .DELIVERED)
        }
        BlazeMessageDAO.shared.delete(data: data)
    }

    private func checkSession(data: BlazeMessageData) {
        guard data.conversationId != User.systemUser && data.userId != User.systemUser else {
            return
        }
        guard data.conversationId != currentAccountId else {
            return
        }
        let participantSession = ParticipantSessionDAO.shared.getParticipantSession(conversationId: data.conversationId, userId: data.userId, sessionId: data.sessionId)
        if participantSession == nil {
            let session = ParticipantSession(conversationId: data.conversationId,
                                             userId: data.userId,
                                             sessionId: data.sessionId,
                                             sentToServer: nil,
                                             createdAt: Date().toUTCString(),
                                             publicKey: nil)
            UserDatabase.current.save(session)
        }
    }

    private func processUnknownMessage(data: BlazeMessageData) {
        var unknownMessage = Message.createMessage(messageId: data.messageId,
                                                   category: data.category,
                                                   conversationId: data.conversationId,
                                                   createdAt: data.createdAt,
                                                   userId: data.getSenderId())
        unknownMessage.status = MessageStatus.UNKNOWN.rawValue
        unknownMessage.content = data.data
        MessageDAO.shared.insertMessage(message: unknownMessage, messageSource: data.source, silentNotification: data.silentNotification)
    }

    private func processBadMessage(data: BlazeMessageData) {
        ReceiveMessageService.shared.updateRemoteMessageStatus(messageId: data.messageId, status: .DELIVERED)
        BlazeMessageDAO.shared.delete(data: data)
    }
    
    private func processCallMessage(data: BlazeMessageData) {
        guard data.category.hasPrefix("WEBRTC_") || data.category.hasPrefix("KRAKEN_") else {
            return
        }
        _ = syncUser(userId: data.getSenderId())
        updateRemoteMessageStatus(messageId: data.messageId, status: .DELIVERED)
        MessageHistoryDAO.shared.replaceMessageHistory(messageId: data.messageId)
        Self.callMessageCoordinator.handleIncomingBlazeMessageData(data)
    }
    
    private func processAppButton(data: BlazeMessageData) {
        guard data.category == MessageCategory.APP_BUTTON_GROUP.rawValue else {
            return
        }
        guard let appButtonData = Data(base64Encoded: data.data), let _ = try? JSONDecoder.default.decode([AppButtonData].self, from: appButtonData) else {
            processUnknownMessage(data: data)
            updateRemoteMessageStatus(messageId: data.messageId, status: .DELIVERED)
            return
        }

        _ = syncUser(userId: data.getSenderId())

        let message = Message.createMessage(appMessage: data)
        MessageDAO.shared.insertMessage(message: message, messageSource: data.source, silentNotification: data.silentNotification)
        updateRemoteMessageStatus(messageId: data.messageId, status: .DELIVERED)
    }

    private func processAppCard(data: BlazeMessageData) {
        guard data.category == MessageCategory.APP_CARD.rawValue else {
            return
        }
        guard let appCardData = Data(base64Encoded: data.data), let appCard = try? JSONDecoder.default.decode(AppCardData.self, from: appCardData) else {
            processUnknownMessage(data: data)
            updateRemoteMessageStatus(messageId: data.messageId, status: .DELIVERED)
            return
        }
        if let appId = appCard.appId {
            guard !appId.isEmpty, UUID(uuidString: appId) != nil else {
                processUnknownMessage(data: data)
                updateRemoteMessageStatus(messageId: data.messageId, status: .DELIVERED)
                return
            }
            syncApp(appId: appId, cardUpdatedAt: appCard.updatedAt)
        }
        _ = syncUser(userId: data.getSenderId())

        let message = Message.createMessage(appMessage: data)
        MessageDAO.shared.insertMessage(message: message, messageSource: data.source, silentNotification: data.silentNotification)
        updateRemoteMessageStatus(messageId: data.messageId, status: .DELIVERED)
    }

    private func syncApp(appId: String, cardUpdatedAt: String?) {
        guard !appId.isEmpty else {
            return
        }
        let app = AppDAO.shared.getApp(appId: appId)
        guard app == nil || app?.updatedAt != cardUpdatedAt else {
            return
        }
        if case let .success(response) = UserSessionAPI.showUser(userId: appId) {
            UserDAO.shared.updateUsers(users: [response], sendNotificationAfterFinished: false)
        } else {
            ConcurrentJobQueue.shared.addJob(job: RefreshUserJob(userIds: [appId]))
        }
    }

    private func processPinMessage(data: BlazeMessageData) {
        guard data.category == MessageCategory.MESSAGE_PIN.rawValue else {
            return
        }
        defer {
            updateRemoteMessageStatus(messageId: data.messageId, status: .DELIVERED)
        }
        guard ConversationDAO.shared.isExist(conversationId: data.conversationId),
              let base64Data = Data(base64Encoded: data.data),
              let pinData = (try? JSONDecoder.default.decode(TransferPinData.self, from: base64Data)),
              let action = TransferPinAction(rawValue: pinData.action)
        else {
            Logger.conversation(id: data.conversationId).error(category: "ParsePin", message: "Invalid TransferPinData: \(data.data)")
            ReceiveMessageService.shared.processUnknownMessage(data: data)
            return
        }
        switch action {
        case .pin:
            for messageId in pinData.messageIds {
                guard let fullMessage = MessageDAO.shared.getFullMessage(messageId: messageId) else {
                    let message = Message.createMessage(messageId: data.messageId,
                                                        conversationId: data.conversationId,
                                                        userId: data.userId,
                                                        category: data.category,
                                                        status: MessageStatus.DELIVERED.rawValue,
                                                        action: pinData.action,
                                                        createdAt: data.createdAt)
                    MessageDAO.shared.insertMessage(message: message, messageSource: data.source, silentNotification: data.silentNotification)
                    continue
                }
                let pinLocalContent = PinMessage.LocalContent(category: fullMessage.category, content: fullMessage.content)
                let content: String
                if let data = try? JSONEncoder.default.encode(pinLocalContent), let localContent = String(data: data, encoding: .utf8) {
                    content = localContent
                } else {
                    content = ""
                }
                let mention: MessageMention?
                if pinLocalContent.category.hasSuffix("_TEXT"), let content = pinLocalContent.content {
                    mention = MessageMention(conversationId: data.conversationId,
                                             messageId: data.messageId,
                                             content: content,
                                             addMeIntoMentions: false,
                                             hasRead: { _ in true })
                } else {
                    mention = nil
                }
                let message = Message.createMessage(messageId: data.messageId,
                                                    conversationId: data.conversationId,
                                                    userId: data.userId,
                                                    category: data.category,
                                                    content: content,
                                                    status: MessageStatus.DELIVERED.rawValue,
                                                    action: pinData.action,
                                                    quoteMessageId: messageId,
                                                    createdAt: data.createdAt)
                PinMessageDAO.shared.save(referencedItem: fullMessage,
                                          source: data.source,
                                          silentNotification: data.silentNotification,
                                          pinMessage: message,
                                          mention: mention)
            }
        case .unpin:
            PinMessageDAO.shared.delete(messageIds: pinData.messageIds, conversationId: data.conversationId)
        }
    }
    
    private func processRecallMessage(data: BlazeMessageData) {
        guard data.category == MessageCategory.MESSAGE_RECALL.rawValue else {
            return
        }

        updateRemoteMessageStatus(messageId: data.messageId, status: .READ)
        MessageHistoryDAO.shared.replaceMessageHistory(messageId: data.messageId)

        if let base64Data = Data(base64Encoded: data.data), let plainData = (try? JSONDecoder.default.decode(TransferRecallData.self, from: base64Data)), !plainData.messageId.isEmpty, let message = MessageDAO.shared.getFullMessage(messageId: plainData.messageId) {
            MessageDAO.shared.recallMessage(message: message)
        }
    }

    private func processSignalMessage(data: BlazeMessageData) {
        guard data.category.hasPrefix("SIGNAL_") else {
            return
        }

        let username = UserDAO.shared.getUser(userId: data.userId)?.fullName ?? data.userId

        if data.category == MessageCategory.SIGNAL_KEY.rawValue {
            updateRemoteMessageStatus(messageId: data.messageId, status: .READ)
            MessageHistoryDAO.shared.replaceMessageHistory(messageId: data.messageId)
        } else {
            updateRemoteMessageStatus(messageId: data.messageId, status: .DELIVERED)
        }

        let decoded = SignalProtocol.shared.decodeMessageData(encoded: data.data)
        do {
            try SignalProtocol.shared.decrypt(groupId: data.conversationId, senderId: data.userId, keyType: decoded.keyType, cipherText: decoded.cipher, category: data.category, sessionId: data.sessionId, callback: { (plain) in
                if data.category != MessageCategory.SIGNAL_KEY.rawValue {
                    let plainText = String(data: plain, encoding: .utf8)!
                    if let messageId = decoded.resendMessageId {
                        self.processRedecryptMessage(data: data, messageId: messageId, plainText: plainText)
                        self.updateRemoteMessageStatus(messageId: data.messageId, status: .READ)
                        MessageHistoryDAO.shared.replaceMessageHistory(messageId: data.messageId)
                    } else {
                        if ["_TEXT", "_POST", "_LOCATION", "_TRANSCRIPT"].contains(where: data.category.hasSuffix(_:)) {
                            self.processDecryptSuccess(data: data, decryptedData: plain)
                        } else if let decryptedData = Data(base64Encoded: plainText) {
                            self.processDecryptSuccess(data: data, decryptedData: decryptedData)
                        } else {
                            self.processUnknownMessage(data: data)
                        }
                    }
                } else {
                    if data.userId != myUserId {
                        let userInfo = [
                            Self.UserInfoKey.conversationId: data.conversationId,
                            Self.UserInfoKey.userId: data.userId,
                            Self.UserInfoKey.sessionId: data.sessionId
                        ]
                        NotificationCenter.default.post(name: Self.senderKeyDidChangeNotification, object: self, userInfo: userInfo)
                    }
                }
            })
            let status = RatchetSenderKeyDAO.shared.getRatchetSenderKeyStatus(groupId: data.conversationId, senderId: data.userId, sessionId: data.sessionId)
            let info: Logger.UserInfo = [
                "username": username,
                "category": data.category,
                "createdAt": data.createdAt,
                "status": status ?? "(null)",
                "source": data.source,
                "resendMessageId": decoded.resendMessageId ?? "(null)",
                "deviceId": SignalProtocol.convertSessionIdToDeviceId(data.sessionId),
            ]
            Logger.conversation(id: data.conversationId).info(category: "ProcessSignalMessage", message: "Decrypted message: \(data.messageId)", userInfo: info)
            if status == RatchetStatus.REQUESTING.rawValue {
                RatchetSenderKeyDAO.shared.deleteRatchetSenderKey(groupId: data.conversationId, senderId: data.userId, sessionId: data.sessionId)
                self.requestResendMessage(conversationId: data.conversationId, userId: data.userId, sessionId: data.sessionId)
            }
        } catch {
            let info: Logger.UserInfo = [
                "username": username,
                "category": data.category,
                "messageType": CiphertextMessage.MessageType.toString(rawValue: decoded.keyType),
                "sessionId": data.sessionId,
                "createdAt": data.createdAt,
                "source": data.source,
                "resendMessageId": decoded.resendMessageId ?? "(null)",
                "error": error,
            ]
            Logger.conversation(id: data.conversationId).info(category: "ProcessSignalMessage", message: "Failed to decrypt message: \(data.messageId)", userInfo: info)
            if let err = error as? SignalError, err != SignalError.noSession {
                var userInfo = [String: Any]()
                userInfo["conversationId"] = data.conversationId
                userInfo["keyType"] = CiphertextMessage.MessageType.toString(rawValue: decoded.keyType)
                userInfo["category"] = data.category
                userInfo["messageId"] = data.messageId
                userInfo["resendMessageId"] = decoded.resendMessageId ?? ""
                userInfo["source"] = data.source
                userInfo["sessionId"] = data.sessionId
                userInfo["error"] = "\(error)"
                userInfo["senderUserId"] = data.userId
                userInfo["signalErrorCode"] = "\(err.rawValue)"
                if data.category == MessageCategory.SIGNAL_KEY.rawValue {
                    userInfo["containsSession"] = "\(SignalProtocol.shared.containsSession(recipient: data.userId))"
                    userInfo["sessionCount"] = "\(SessionDAO.shared.getCount())"
                    userInfo["localIentity"] = IdentityDAO.shared.getLocalIdentity()?.address ?? ""
                    userInfo["ratchetSenderKeyStatus"] =  RatchetSenderKeyDAO.shared.getRatchetSenderKeyStatus(groupId: data.conversationId, senderId: data.userId, sessionId: data.sessionId) ?? ""
                }
                userInfo["createdAt"] = data.createdAt
                reporter.report(error: MixinServicesError.decryptMessage(userInfo))
            }
            
            guard !MessageDAO.shared.isExist(messageId: data.messageId) else {
                reporter.report(error: MixinServicesError.duplicatedMessage)
                return
            }
            guard decoded.resendMessageId == nil else {
                return
            }
            if (data.category == MessageCategory.SIGNAL_KEY.rawValue) {
                RatchetSenderKeyDAO.shared.deleteRatchetSenderKey(groupId: data.conversationId, senderId: data.userId, sessionId: data.sessionId)
                refreshKeys(conversationId: data.conversationId)
            } else {
                insertFailedMessage(data: data)
                refreshKeys(conversationId: data.conversationId)
                let status = RatchetSenderKeyDAO.shared.getRatchetSenderKeyStatus(groupId: data.conversationId, senderId: data.userId, sessionId: data.sessionId)
                if status == nil {
                    requestResendKey(conversationId: data.conversationId, recipientId: data.userId, messageId: data.messageId, sessionId: data.sessionId)
                }
            }
        }
    }
    
    private func processEncryptedMessage(data: BlazeMessageData) {
        guard data.category.hasPrefix("ENCRYPTED_") else {
            return
        }
        guard
            let cipher = Data(base64Encoded: data.data),
            let pk = RequestSigning.edDSAPrivateKey,
            let sidString = LoginManager.shared.account?.session_id,
            let mySessionId = UUID(uuidString: sidString)
        else {
            let hasSessionId = LoginManager.shared.account?.session_id != nil
            let info = [
                "is_cipher_valid": Data(base64Encoded: data.data) != nil,
                "has_pk": RequestSigning.edDSAPrivateKey != nil,
                "has_sid": hasSessionId,
                "is_sid_valid": hasSessionId && UUID(uuidString: LoginManager.shared.account?.session_id ?? "") != nil
            ]
            Logger.conversation(id: data.conversationId).error(category: "EncryptedBotMessage", message: "Failed to decrypt", userInfo: info)
            reporter.report(error: MixinServicesError.decryptBotMessage(info))
            updateRemoteMessageStatus(messageId: data.messageId, status: .DELIVERED)
            ReceiveMessageService.shared.processUnknownMessage(data: data)
            return
        }
        do {
            let decryptedData = try EncryptedProtocol.decrypt(cipher: cipher, with: pk, sessionId: mySessionId)
            _ = syncUser(userId: data.getSenderId())
            processDecryptSuccess(data: data, decryptedData: decryptedData)
        } catch {
            reporter.report(error: error)
            ReceiveMessageService.shared.processUnknownMessage(data: data)
        }
        updateRemoteMessageStatus(messageId: data.messageId, status: .DELIVERED)
    }
    
    private func refreshKeys(conversationId: String) {
        let now = Date().timeIntervalSince1970
        guard now - (refreshRefreshOneTimePreKeys[conversationId] ?? 0) > 60 else {
            return
        }
        refreshRefreshOneTimePreKeys[conversationId] = now
        Logger.conversation(id: conversationId).info(category: "ProcessSignalMessage", message: "Refreshed keys")
        refreshKeys()
    }

    private func refreshKeys() {
        let countBlazeMessage = BlazeMessage(action: BlazeMessageAction.countSignalKeys.rawValue)
        guard let count = deliverKeys(blazeMessage: countBlazeMessage)?.toSignalKeyCount(), count.preKeyCount <= PreKeyUtil.prekeyMiniNum else {
            return
        }
        do {
            let request = try PreKeyUtil.generateKeys()
            let blazeMessage = BlazeMessage(params: BlazeMessageParam(syncSignalKeys: request), action: BlazeMessageAction.syncSignalKeys.rawValue)
            deliverNoThrow(blazeMessage: blazeMessage)
        } catch {
            reporter.report(error: error)
        }
    }
    
    private func processDecryptSuccess(data: BlazeMessageData, decryptedData: Data) {
        if data.category.hasSuffix("_TEXT") || data.category.hasSuffix("_POST") {
            guard let content = String(data: decryptedData, encoding: .utf8) else {
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            let message = Message.createMessage(textMessage: content, data: data)
            MessageDAO.shared.insertMessage(message: message, messageSource: data.source, silentNotification: data.silentNotification)
        } else if data.category.hasSuffix("_IMAGE") || data.category.hasSuffix("_VIDEO") {
            guard let transferMediaData = (try? JSONDecoder.default.decode(TransferAttachmentData.self, from: decryptedData)) else {
                Logger.conversation(id: data.conversationId).error(category: "DecryptSuccess", message: "Invalid data for category: \(data.category), data: \(String(data: decryptedData, encoding: .utf8))")
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            guard let height = transferMediaData.height, let width = transferMediaData.width, height > 0, width > 0 else {
                Logger.conversation(id: data.conversationId).error(category: "DecryptSuccess", message: "Invalid TransferAttachmentData for category: \(data.category), data: \(String(data: decryptedData, encoding: .utf8))")
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }

            if transferMediaData.mimeType?.isEmpty ?? true {
                let userInfo: [String: Any] = [
                    "messageId": data.messageId,
                    "width" : width,
                    "height" : height,
                    "size" : transferMediaData.size,
                    "userId": data.userId
                ]
                let error = MixinServicesError.nilMimeType(userInfo)
                reporter.report(error: error)
            }

            let message = Message.createMessage(mediaData: transferMediaData, data: data)
            MessageDAO.shared.insertMessage(message: message, messageSource: data.source, silentNotification: data.silentNotification)
        } else if data.category.hasSuffix("_LIVE") {
            guard let live = (try? JSONDecoder.default.decode(TransferLiveData.self, from: decryptedData)) else {
                Logger.conversation(id: data.conversationId).error(category: "DecryptSuccess", message: "Invalid TransferLiveData for category: \(data.category), data: \(String(data: decryptedData, encoding: .utf8))")
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            let message = Message.createMessage(liveData: live,
                                                content: String(data: decryptedData, encoding: .utf8),
                                                data: data)
            MessageDAO.shared.insertMessage(message: message, messageSource: data.source, silentNotification: data.silentNotification)
        } else if data.category.hasSuffix("_DATA")  {
            guard let transferMediaData = (try? JSONDecoder.default.decode(TransferAttachmentData.self, from: decryptedData)) else {
                Logger.conversation(id: data.conversationId).error(category: "DecryptSuccess", message: "Invalid TransferAttachmentData for category: \(data.category), data: \(String(data: decryptedData, encoding: .utf8))")
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            guard transferMediaData.size > 0 else {
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            let message = Message.createMessage(mediaData: transferMediaData, data: data)
            MessageDAO.shared.insertMessage(message: message, messageSource: data.source, silentNotification: data.silentNotification)
        } else if data.category.hasSuffix("_AUDIO") {
            guard let transferMediaData = (try? JSONDecoder.default.decode(TransferAttachmentData.self, from: decryptedData)) else {
                Logger.conversation(id: data.conversationId).error(category: "DecryptSuccess", message: "Invalid TransferAttachmentData for category: \(data.category), data: \(String(data: decryptedData, encoding: .utf8))")
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            let message = Message.createMessage(mediaData: transferMediaData, data: data)
            MessageDAO.shared.insertMessage(message: message, messageSource: data.source, silentNotification: data.silentNotification)
            let job = AttachmentDownloadJob(message: message)
            ConcurrentJobQueue.shared.addJob(job: job)
        } else if data.category.hasSuffix("_STICKER") {
            guard let transferStickerData = parseSticker(data: data, decryptedData: decryptedData) else {
                return
            }
            let message = Message.createMessage(stickerData: transferStickerData, data: data)
            MessageDAO.shared.insertMessage(message: message, messageSource: data.source, silentNotification: data.silentNotification)
        } else if data.category.hasSuffix("_CONTACT") {
            guard let transferData = (try? JSONDecoder.default.decode(TransferContactData.self, from: decryptedData)) else {
                Logger.conversation(id: data.conversationId).error(category: "DecryptSuccess", message: "Invalid TransferContactData for category: \(data.category), data: \(String(data: decryptedData, encoding: .utf8))")
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            guard !transferData.userId.isEmpty, UUID(uuidString: transferData.userId) != nil else {
                Logger.conversation(id: data.conversationId).error(category: "DecryptSuccess", message: "Invalid TransferContactData for category: \(data.category), data: \(String(data: decryptedData, encoding: .utf8))")
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            guard syncUser(userId: transferData.userId) else {
                return
            }
            let message = Message.createMessage(contactData: transferData, data: data)
            MessageDAO.shared.insertMessage(message: message, messageSource: data.source, silentNotification: data.silentNotification)
        } else if data.category.hasSuffix("_LOCATION") {
            guard (try? JSONDecoder.default.decode(Location.self, from: decryptedData)) != nil else {
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            guard let content = String(data: decryptedData, encoding: .utf8) else {
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            let message = Message.createLocationMessage(content: content, data: data)
            MessageDAO.shared.insertMessage(message: message, messageSource: data.source, silentNotification: data.silentNotification)
        } else if data.category.hasSuffix("_TRANSCRIPT") {
            guard let (content, children, hasAttachment) = parseTranscript(decryptedData: decryptedData, transcriptId: data.messageId) else {
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            guard !children.isEmpty else {
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            let message = Message.createTranscriptMessage(content: content,
                                                          mediaStatus: hasAttachment ? .PENDING : .DONE,
                                                          data: data)
            MessageDAO.shared.insertMessage(message: message, children: children, messageSource: data.source, silentNotification: data.silentNotification)
        }
    }
    
    private func insertFailedMessage(data: BlazeMessageData) {
        let availableCategories: [MessageCategory] = [
            .SIGNAL_TEXT, .SIGNAL_IMAGE, .SIGNAL_DATA, .SIGNAL_VIDEO, .SIGNAL_LIVE,
            .SIGNAL_AUDIO, .SIGNAL_CONTACT, .SIGNAL_STICKER, .SIGNAL_POST, .SIGNAL_LOCATION,
            .SIGNAL_TRANSCRIPT
        ]
        guard availableCategories.contains(where: { data.category == $0.rawValue }) else {
            return
        }
        var failedMessage = Message.createMessage(messageId: data.messageId, category: data.category, conversationId: data.conversationId, createdAt: data.createdAt, userId: data.userId)
        failedMessage.status = MessageStatus.FAILED.rawValue
        failedMessage.content = data.data
        failedMessage.quoteMessageId = data.quoteMessageId.isEmpty ? nil : data.quoteMessageId
        MessageDAO.shared.insertMessage(message: failedMessage, messageSource: data.source, silentNotification: data.silentNotification)
    }

    private func processRedecryptMessage(data: BlazeMessageData, messageId: String, plainText: String) {
        let quoteMessage = MessageDAO.shared.getNonFailedMessage(messageId: data.quoteMessageId)

        defer {
            if let quoteMessage = quoteMessage, let quoteContent = try? JSONEncoder.default.encode(quoteMessage) {
                MessageDAO.shared.update(quoteContent: quoteContent, for: messageId)
            }
        }
        
        switch data.category {
        case MessageCategory.SIGNAL_TEXT.rawValue:
            let mention = MessageMention(conversationId: data.conversationId,
                                         messageId: messageId,
                                         content: plainText,
                                         addMeIntoMentions: data.userId != myUserId && quoteMessage?.userId == myUserId,
                                         hasRead: { data.userId == myUserId || $0[myIdentityNumber] == nil })
            MessageDAO.shared.updateMessageContentAndStatus(content: plainText,
                                                            status: Message.getStatus(data: data),
                                                            mention: mention,
                                                            messageId: messageId,
                                                            category: data.category,
                                                            conversationId: data.conversationId,
                                                            messageSource: data.source,
                                                            silentNotification: data.silentNotification)
        case MessageCategory.SIGNAL_POST.rawValue:
            MessageDAO.shared.updateMessageContentAndStatus(content: plainText,
                                                            status: Message.getStatus(data: data),
                                                            mention: nil,
                                                            messageId: messageId,
                                                            category: data.category,
                                                            conversationId: data.conversationId,
                                                            messageSource: data.source,
                                                            silentNotification: data.silentNotification)
        case MessageCategory.SIGNAL_LOCATION.rawValue:
            guard let contentData = plainText.data(using: .utf8) else {
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            guard (try? JSONDecoder.default.decode(Location.self, from: contentData)) != nil else {
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            MessageDAO.shared.updateMessageContentAndStatus(content: plainText,
                                                            status: Message.getStatus(data: data),
                                                            mention: nil,
                                                            messageId: messageId,
                                                            category: data.category,
                                                            conversationId: data.conversationId,
                                                            messageSource: data.source,
                                                            silentNotification: data.silentNotification)
        case MessageCategory.SIGNAL_IMAGE.rawValue, MessageCategory.SIGNAL_VIDEO.rawValue:
            guard let base64Data = Data(base64Encoded: plainText), let transferMediaData = (try? JSONDecoder.default.decode(TransferAttachmentData.self, from: base64Data)) else {
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            guard let height = transferMediaData.height, let width = transferMediaData.width, height > 0, width > 0 else {
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            MessageDAO.shared.updateMediaMessage(mediaData: transferMediaData, status: Message.getStatus(data: data), messageId: messageId, category: data.category, conversationId: data.conversationId, mediaStatus: .PENDING, messageSource: data.source, silentNotification: data.silentNotification)
        case MessageCategory.SIGNAL_DATA.rawValue:
            guard let base64Data = Data(base64Encoded: plainText), let transferMediaData = (try? JSONDecoder.default.decode(TransferAttachmentData.self, from: base64Data)) else {
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            guard transferMediaData.size > 0 else {
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            MessageDAO.shared.updateMediaMessage(mediaData: transferMediaData, status: Message.getStatus(data: data), messageId: messageId, category: data.category, conversationId: data.conversationId, mediaStatus: .PENDING, messageSource: data.source, silentNotification: data.silentNotification)
        case MessageCategory.SIGNAL_AUDIO.rawValue:
            guard let base64Data = Data(base64Encoded: plainText), let transferMediaData = (try? JSONDecoder.default.decode(TransferAttachmentData.self, from: base64Data)) else {
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            MessageDAO.shared.updateMediaMessage(mediaData: transferMediaData, status: Message.getStatus(data: data), messageId: messageId, category: data.category, conversationId: data.conversationId, mediaStatus: .PENDING, messageSource: data.source, silentNotification: data.silentNotification)
            let job = AttachmentDownloadJob(messageId: messageId)
            ConcurrentJobQueue.shared.addJob(job: job)
        case MessageCategory.SIGNAL_LIVE.rawValue:
            guard let base64Data = Data(base64Encoded: plainText), let liveData = (try? JSONDecoder.default.decode(TransferLiveData.self, from: base64Data)) else {
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            MessageDAO.shared.updateLiveMessage(liveData: liveData, content: plainText.base64Decoded(), status: Message.getStatus(data: data), messageId: messageId, category: data.category, conversationId: data.conversationId, messageSource: data.source, silentNotification: data.silentNotification)
        case MessageCategory.SIGNAL_STICKER.rawValue:
            guard let decryptedData = plainText.data(using: .utf8), let transferStickerData = parseSticker(data: data, decryptedData: decryptedData) else {
                return
            }
            MessageDAO.shared.updateStickerMessage(stickerData: transferStickerData, status: Message.getStatus(data: data), messageId: messageId, category: data.category, conversationId: data.conversationId, messageSource: data.source, silentNotification: data.silentNotification)
        case MessageCategory.SIGNAL_CONTACT.rawValue:
            guard let base64Data = Data(base64Encoded: plainText), let transferData = (try? JSONDecoder.default.decode(TransferContactData.self, from: base64Data)) else {
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            guard !transferData.userId.isEmpty, UUID(uuidString: transferData.userId) != nil else {
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            guard syncUser(userId: transferData.userId) else {
                return
            }
            MessageDAO.shared.updateContactMessage(transferData: transferData, status: Message.getStatus(data: data), messageId: messageId, category: data.category, conversationId: data.conversationId, messageSource: data.source, silentNotification: data.silentNotification)
        case MessageCategory.SIGNAL_TRANSCRIPT.rawValue:
            guard
                let decryptedData = plainText.data(using: .utf8),
                let (content, children, hasAttachment) = parseTranscript(decryptedData: decryptedData, transcriptId: messageId)
            else {
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            guard !children.isEmpty else {
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return
            }
            MessageDAO.shared.updateTranscriptMessage(children: children,
                                                      status: Message.getStatus(data: data),
                                                      mediaStatus: hasAttachment ? .PENDING : .DONE,
                                                      content: content,
                                                      messageId: messageId,
                                                      category: data.category,
                                                      conversationId: data.conversationId,
                                                      messageSource: data.source,
                                                      silentNotification: data.silentNotification)
        default:
            break
        }
    }
    
    private func parseSticker(data: BlazeMessageData, decryptedData: Data) -> TransferStickerData? {
        guard let transferStickerData = (try? JSONDecoder.default.decode(TransferStickerData.self, from: decryptedData)) else {
            Logger.conversation(id: data.conversationId).error(category: "ParseSticker", message: "Invalid TransferStickerData: \(String(data: decryptedData, encoding: .utf8))")
            ReceiveMessageService.shared.processUnknownMessage(data: data)
            return nil
        }

        if let stickerId = transferStickerData.stickerId {
            guard !stickerId.isEmpty, UUID(uuidString: stickerId) != nil else {
                Logger.conversation(id: data.conversationId).error(category: "ParseSticker", message: "Invalid TransferStickerData: \(String(data: decryptedData, encoding: .utf8))")
                ReceiveMessageService.shared.processUnknownMessage(data: data)
                return nil
            }
            guard !StickerDAO.shared.isExist(stickerId: stickerId) else {
                return transferStickerData
            }

            repeat {
                switch StickerAPI.sticker(stickerId: stickerId) {
                case let .success(sticker):
                    StickerDAO.shared.insertOrUpdateSticker(sticker: sticker)
                    if let sticker = StickerDAO.shared.getSticker(stickerId: sticker.stickerId) {
                        StickerPrefetcher.prefetch(stickers: [sticker])
                    }
                    return transferStickerData
                case .failure(.notFound):
                    return nil
                case let .failure(error):
                    checkNetworkAndWebSocket()
                }
            } while LoginManager.shared.isLoggedIn
            return nil
        } else if let stickerName = transferStickerData.name, let albumId = transferStickerData.albumId, let sticker = StickerDAO.shared.getSticker(albumId: albumId, name: stickerName) {
            return TransferStickerData(stickerId: sticker.stickerId, name: nil, albumId: nil)
        }
        return nil
    }
    
    private func parseTranscript(decryptedData: Data, transcriptId: String) -> (content: String, children: [TranscriptMessage], hasAttachment: Bool)? {
        var hasAttachment = false
        
        guard let descendants = try? JSONDecoder.default.decode([TranscriptMessage].self, from: decryptedData) else {
            return nil
        }
        
        let children = descendants.filter { $0.transcriptId == transcriptId }
        let localContents = children
            .sorted { $0.createdAt < $1.createdAt }
            .map(TranscriptMessage.LocalContent.init)
        let content: String
        if let data = try? JSONEncoder.default.encode(localContents), let localContent = String(data: data, encoding: .utf8) {
            content = localContent
        } else {
            content = ""
        }
        
        var absentUserIds: Set<String> = []
        for child in children {
            if let id = child.userId {
                if let fullname = UserDAO.shared.getFullname(userId: id) {
                    child.userFullName = fullname
                } else {
                    absentUserIds.insert(id)
                }
            }
            if MessageCategory.allMediaCategoriesString.contains(child.category) {
                hasAttachment = true
                child.mediaStatus = MediaStatus.PENDING.rawValue
            } else if child.category.hasSuffix("_STICKER") {
                guard let stickerId = child.stickerId, UUID(uuidString: stickerId) != nil else {
                    child.stickerId = nil
                    continue
                }
                if StickerDAO.shared.isExist(stickerId: stickerId) {
                    continue
                }
                ConcurrentJobQueue.shared.addJob(job: RefreshStickerJob(.sticker(id: stickerId)))
            }
        }
        if !absentUserIds.isEmpty {
            let job = RefreshUserJob(userIds: Array(absentUserIds))
            ConcurrentJobQueue.shared.addJob(job: job)
        }
        
        return (content, children, hasAttachment)
    }
    
    private func syncConversation(data: BlazeMessageData) {
        guard data.conversationId != User.systemUser && data.conversationId != myUserId else {
            return
        }

        let conversationStatus = ConversationDAO.shared.getConversationStatus(conversationId: data.conversationId)
        guard conversationStatus != ConversationStatus.SUCCESS.rawValue else {
            return
        }

        if conversationStatus == ConversationStatus.START.rawValue && ConversationDAO.shared.getConversationCategory(conversationId: data.conversationId) == ConversationCategory.GROUP.rawValue {
            // from NewGroupViewController
            return
        }

        switch ConversationAPI.getConversation(conversationId: data.conversationId) {
        case let .success(response):
            let userIds = response.participants
                .map{ $0.userId }
                .filter{ $0 != currentAccountId }
            if userIds.count > 0 {
                switch UserSessionAPI.showUsers(userIds: userIds) {
                case let .success(users):
                    UserDAO.shared.updateUsers(users: users)
                case .failure:
                    break
                }
            }

            if conversationStatus == nil || conversationStatus == ConversationStatus.START.rawValue {
                ConversationDAO.shared.createConversation(conversation: response, targetStatus: .SUCCESS)
            } else {
                ConversationDAO.shared.updateConversation(conversation: response)
            }
            CircleConversationDAO.shared.update(conversation: response)
            return
        case .failure:
            break
        }
        if conversationStatus == nil {
            ConversationDAO.shared.createPlaceConversation(conversationId: data.conversationId, ownerId: data.userId)
            ConcurrentJobQueue.shared.addJob(job: CreateConversationJob(conversationId: data.conversationId))
        } else {
            ConcurrentJobQueue.shared.addJob(job: RefreshConversationJob(conversationId: data.conversationId))
        }
    }

    @discardableResult
    private func checkUser(userId: String, tryAgain: Bool = false) -> ParticipantStatus {
        guard !userId.isEmpty else {
            return .ERROR
        }
        guard User.systemUser != userId, userId != currentAccountId, !UserDAO.shared.isExist(userId: userId) else {
            return .SUCCESS
        }
        switch UserSessionAPI.showUser(userId: userId) {
        case let .success(response):
            UserDAO.shared.updateUsers(users: [response])
            return .SUCCESS
        case .failure(.notFound):
            return .ERROR
        case .failure:
            if tryAgain {
                ConcurrentJobQueue.shared.addJob(job: RefreshUserJob(userIds: [userId]))
            }
            return .START
        }
    }

    private func syncUser(userId: String) -> Bool {
        guard !userId.isEmpty else {
            return false
        }
        guard User.systemUser != userId, userId != currentAccountId, !UserDAO.shared.isExist(userId: userId) else {
            return true
        }

        repeat {
            switch UserSessionAPI.showUser(userId: userId) {
            case let .success(response):
                UserDAO.shared.updateUsers(users: [response])
                return true
            case .failure(.unauthorized):
                return false
            case .failure(.notFound):
                return false
            case .failure:
                checkNetworkAndWebSocket()
            }
        } while LoginManager.shared.isLoggedIn

        return false
    }

    private func processPlainMessage(data: BlazeMessageData) {
        guard data.category.hasPrefix("PLAIN_") else {
            return
        }

        switch data.category {
        case MessageCategory.PLAIN_JSON.rawValue:
            defer {
                updateRemoteMessageStatus(messageId: data.messageId, status: .READ)
                MessageHistoryDAO.shared.replaceMessageHistory(messageId: data.messageId)
            }
            guard let base64Data = Data(base64Encoded: data.data), let plainData = (try? JSONDecoder.default.decode(PlainJsonMessagePayload.self, from: base64Data)) else {
                return
            }

            if let user = UserDAO.shared.getUser(userId: data.userId) {
                let info: Logger.UserInfo = [
                    "user": user.fullName,
                    "category": data.category,
                    "action": plainData.action,
                    "messageId": data.messageId,
                    "createdAt": data.createdAt,
                ]
                Logger.conversation(id: data.conversationId).info(category: "ReceiveMessageService", message: "Received plain message", userInfo: info)
            }
            switch plainData.action {
            case PlainDataAction.RESEND_KEY.rawValue:
                guard SignalProtocol.shared.containsUserSession(recipientId: data.userId) else {
                    return
                }
                SendMessageService.shared.sendMessage(conversationId: data.conversationId, userId: data.userId, sessionId: data.sessionId, action: .RESEND_KEY)
            case PlainDataAction.RESEND_MESSAGES.rawValue:
                guard let messageIds = plainData.messages, messageIds.count > 0 else {
                    return
                }
                SendMessageService.shared.resendMessages(conversationId: data.conversationId, userId: data.userId, sessionId: data.sessionId, messageIds: messageIds)
            case PlainDataAction.NO_KEY.rawValue:
                RatchetSenderKeyDAO.shared.deleteRatchetSenderKey(groupId: data.conversationId, senderId: data.userId, sessionId: data.sessionId)
            case PlainDataAction.ACKNOWLEDGE_MESSAGE_RECEIPTS.rawValue:
                guard let ackMessages = plainData.ackMessages else {
                    return
                }

                var readMessageIds = [String]()
                var mentionMessageIds = [String]()
                ackMessages.forEach { (message) in
                    if message.status == MessageStatus.READ.rawValue {
                        readMessageIds.append(message.messageId)
                    } else if message.status == MessageMentionStatus.MENTION_READ.rawValue {
                        mentionMessageIds.append(message.messageId)
                    }
                }

                MessageDAO.shared.batchUpdateMessageStatus(readMessageIds: readMessageIds, mentionMessageIds: mentionMessageIds)
            default:
                break
            }
        case MessageCategory.PLAIN_TEXT.rawValue, MessageCategory.PLAIN_IMAGE.rawValue, MessageCategory.PLAIN_DATA.rawValue, MessageCategory.PLAIN_VIDEO.rawValue, MessageCategory.PLAIN_LIVE.rawValue, MessageCategory.PLAIN_AUDIO.rawValue, MessageCategory.PLAIN_STICKER.rawValue, MessageCategory.PLAIN_CONTACT.rawValue, MessageCategory.PLAIN_POST.rawValue, MessageCategory.PLAIN_LOCATION.rawValue, MessageCategory.PLAIN_TRANSCRIPT.rawValue:
            _ = syncUser(userId: data.getSenderId())
            if let decoded = Data(base64Encoded: data.data) {
                processDecryptSuccess(data: data, decryptedData: decoded)
            } else {
                processUnknownMessage(data: data)
            }
            updateRemoteMessageStatus(messageId: data.messageId, status: .DELIVERED)
        default:
            break
        }
    }

    private func requestResendMessage(conversationId: String, userId: String, sessionId: String?) {
        let messages: [String] = MessageDAO.shared.findFailedMessages(conversationId: conversationId, userId: userId).reversed()
        guard messages.count > 0 else {
            return
        }

        Logger.conversation(id: conversationId).info(category: "ReceiveMessageService", message: "Request resend messages: [\(messages.joined(separator: ","))]")
        let transferPlainData = PlainJsonMessagePayload(action: PlainDataAction.RESEND_MESSAGES.rawValue, messageId: nil, messages: messages, ackMessages: nil)
        let encoded = (try? JSONEncoder.default.encode(transferPlainData).base64EncodedString()) ?? ""
        let messageId = UUID().uuidString.lowercased()
        let params = BlazeMessageParam(conversationId: conversationId, recipientId: userId, category: MessageCategory.PLAIN_JSON.rawValue, data: encoded, status: MessageStatus.SENDING.rawValue, messageId: messageId, sessionId: sessionId)
        let blazeMessage = BlazeMessage(params: params, action: BlazeMessageAction.createMessage.rawValue)
        SendMessageService.shared.sendMessage(conversationId: conversationId, userId: userId, blazeMessage: blazeMessage, action: .REQUEST_RESEND_MESSAGES)
    }

    private func requestResendKey(conversationId: String, recipientId: String, messageId: String, sessionId: String?) {
        let transferPlainData = PlainJsonMessagePayload(action: PlainDataAction.RESEND_KEY.rawValue, messageId: messageId, messages: nil, ackMessages: nil)
        let encoded = (try? JSONEncoder.default.encode(transferPlainData).base64EncodedString()) ?? ""
        let messageId = UUID().uuidString.lowercased()
        let params = BlazeMessageParam(conversationId: conversationId, recipientId: recipientId, category: MessageCategory.PLAIN_JSON.rawValue, data: encoded, status: MessageStatus.SENDING.rawValue, messageId: messageId, sessionId: sessionId)
        let blazeMessage = BlazeMessage(params: params, action: BlazeMessageAction.createMessage.rawValue)
        SendMessageService.shared.sendMessage(conversationId: conversationId, userId: recipientId, blazeMessage: blazeMessage, action: .REQUEST_RESEND_KEY)

        RatchetSenderKeyDAO.shared.setRatchetSenderKeyStatus(groupId: conversationId, senderId: recipientId, status: RatchetStatus.REQUESTING.rawValue, sessionId: sessionId)
    }

    private func updateRemoteMessageStatus(messageId: String, status: MessageStatus) {
        SendMessageService.shared.sendAckMessage(messageId: messageId, status: status)
    }
}

extension ReceiveMessageService {

    private func processSystemMessage(data: BlazeMessageData) {
        guard data.category.hasPrefix("SYSTEM_") else {
            return
        }

        switch data.category {
        case MessageCategory.SYSTEM_CONVERSATION.rawValue:
            messageDispatchQueue.sync {
                processSystemConversationMessage(data: data)
            }
        case MessageCategory.SYSTEM_ACCOUNT_SNAPSHOT.rawValue:
            processSystemSnapshotMessage(data: data)
        case MessageCategory.SYSTEM_SESSION.rawValue:
            processSystemSessionMessage(data: data)
        case MessageCategory.SYSTEM_USER.rawValue:
            processSystemUserMessage(data: data)
        case MessageCategory.SYSTEM_CIRCLE.rawValue:
            processSystemCircleMessage(data: data)
        default:
            break
        }
        updateRemoteMessageStatus(messageId: data.messageId, status: .READ)
    }

    private func processSystemUserMessage(data: BlazeMessageData) {
        guard let base64Data = Data(base64Encoded: data.data), let systemUser = (try? JSONDecoder.default.decode(SystemUserMessagePayload.self, from: base64Data)) else {
            return
        }

        if systemUser.action == SystemUserMessageAction.UPDATE.rawValue {
            ConcurrentJobQueue.shared.addJob(job: RefreshUserJob(userIds: [systemUser.userId]))
        }
    }

    private func processSystemCircleMessage(data: BlazeMessageData) {
        guard let base64Data = Data(base64Encoded: data.data), let systemCircle = (try? JSONDecoder.default.decode(SystemCircleMessagePayload.self, from: base64Data)) else {
            return
        }

        if systemCircle.action == SystemCircleMessageAction.CREATE.rawValue || systemCircle.action == SystemCircleMessageAction.UPDATE.rawValue {
            ConcurrentJobQueue.shared.addJob(job: RefreshCircleJob(circleId: systemCircle.circleId))
        } else if systemCircle.action == SystemCircleMessageAction.ADD.rawValue {
            guard let conversationId = systemCircle.makeConversationIdIfNeeded() else {
                return
            }

            if !CircleDAO.shared.isExist(circleId: systemCircle.circleId) {
                ConcurrentJobQueue.shared.addJob(job: RefreshCircleJob(circleId: systemCircle.circleId))
            }

            let circleConversation = CircleConversation(circleId: systemCircle.circleId, conversationId: conversationId, userId: systemCircle.userId, createdAt: data.updatedAt, pinTime: nil)
            if let userId = systemCircle.userId {
                syncUser(userId: userId)
            }
            CircleConversationDAO.shared.save(circleId: systemCircle.circleId, objects: [circleConversation])
        } else if systemCircle.action == SystemCircleMessageAction.REMOVE.rawValue {
            guard let conversationId = systemCircle.makeConversationIdIfNeeded() else {
                return
            }
            
            CircleConversationDAO.shared.delete(circleId: systemCircle.circleId, conversationId: conversationId)
        } else if systemCircle.action == SystemCircleMessageAction.DELETE.rawValue {
            CircleDAO.shared.delete(circleId: systemCircle.circleId)
        }
    }

    private func processSystemSnapshotMessage(data: BlazeMessageData) {
        guard let base64Data = Data(base64Encoded: data.data), let snapshot = (try? JSONDecoder.default.decode(Snapshot.self, from: base64Data)) else {
            return
        }

        if let opponentId = snapshot.opponentId {
            checkUser(userId: opponentId, tryAgain: true)
        }

        switch AssetAPI.asset(assetId: snapshot.assetId) {
        case let .success(asset):
            AssetDAO.shared.insertOrUpdateAssets(assets: [asset])
        case .failure:
            ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob(assetId: snapshot.assetId))
        }

        if snapshot.type == SnapshotType.deposit.rawValue, let transactionHash = snapshot.transactionHash {
            SnapshotDAO.shared.removePendingDeposits(assetId: snapshot.assetId, transactionHash: transactionHash)
        }

        SnapshotDAO.shared.saveSnapshots(snapshots: [snapshot])
        let message = Message.createMessage(snapshotMesssage: snapshot, data: data)
        MessageDAO.shared.insertMessage(message: message, messageSource: data.source, silentNotification: data.silentNotification)
    }

    private func processSystemSessionMessage(data: BlazeMessageData) {
        guard let base64Data = Data(base64Encoded: data.data), let systemSession = (try? JSONDecoder.default.decode(SystemSessionMessagePayload.self, from: base64Data)) else {
            return
        }

        if systemSession.action == SystemSessionMessageAction.PROVISION.rawValue {
            AppGroupUserDefaults.Account.lastDesktopLoginDate = Date()
            AppGroupUserDefaults.Account.extensionSession = systemSession.sessionId
            SignalProtocol.shared.deleteSession(userId: systemSession.userId)

            Logger.general.info(category: "ProcessSystemSessionMessage", message: "Desktop login")

            ParticipantSessionDAO.shared.provisionSession(userId: systemSession.userId,
                                                          sessionId: systemSession.sessionId,
                                                          publicKey: systemSession.publicKey)
            NotificationCenter.default.post(onMainThread: Self.userSessionDidChangeNotification, object: self)
        } else if (systemSession.action == SystemSessionMessageAction.DESTROY.rawValue) {
            guard AppGroupUserDefaults.Account.extensionSession == systemSession.sessionId else {
                return
            }
            AppGroupUserDefaults.Account.extensionSession = nil
            SignalProtocol.shared.deleteSession(userId: systemSession.userId)

            Logger.general.info(category: "ProcessSystemSessionMessage", message: "Desktop logout")

            JobDAO.shared.clearSessionJob()
            ParticipantSessionDAO.shared.destorySession(userId: systemSession.userId, sessionId: systemSession.sessionId)
            NotificationCenter.default.post(onMainThread: Self.userSessionDidChangeNotification, object: self)
        }
    }

    private func processSystemConversationMessage(data: BlazeMessageData) {
        guard let base64Data = Data(base64Encoded: data.data), let sysMessage = (try? JSONDecoder.default.decode(SystemConversationMessagePayload.self, from: base64Data)) else {
            return
        }

        if sysMessage.action != SystemConversationAction.UPDATE.rawValue {
            syncConversation(data: data)
        }

        let userId = sysMessage.userId ?? data.userId
        let messageId = data.messageId
        var operSuccess = true

        if let participantId = sysMessage.participantId {
            let usernameOrId = UserDAO.shared.getUser(userId: participantId)?.fullName ?? participantId
            Logger.conversation(id: data.conversationId).info(category: "ProcessSystemMessage", message: "Received \(sysMessage.action) from \(usernameOrId), messageId: \(data.messageId), createdAt: \(data.createdAt)")
        }

        if userId == User.systemUser {
            UserDAO.shared.insertSystemUser(userId: userId)
        }

        let message = Message.createMessage(systemMessage: sysMessage.action, participantId: sysMessage.participantId, userId: userId, data: data)

        defer {
            let participantDidChange = operSuccess
                && sysMessage.action != SystemConversationAction.UPDATE.rawValue
                && sysMessage.action != SystemConversationAction.ROLE.rawValue
            if participantDidChange {
                let userInfo = [ReceiveMessageService.UserInfoKey.conversationId: data.conversationId]
                NotificationCenter.default.post(name: ReceiveMessageService.groupConversationParticipantDidChangeNotification, object: self, userInfo: userInfo)
            }
        }
        
        switch sysMessage.action {
        case SystemConversationAction.ADD.rawValue, SystemConversationAction.JOIN.rawValue:
            guard let participantId = sysMessage.participantId, !participantId.isEmpty, participantId != User.systemUser else {
                return
            }
            let status = checkUser(userId: participantId, tryAgain: true)
            operSuccess = ParticipantDAO.shared.addParticipant(message: message,
                                                               conversationId: data.conversationId,
                                                               participantId: participantId,
                                                               updatedAt: data.updatedAt,
                                                               status: status,
                                                               source: data.source,
                                                               silentNotification: data.silentNotification)

            if participantId == currentAccountId {
                ConcurrentJobQueue.shared.addJob(job: RefreshConversationJob(conversationId: data.conversationId))
            } else {
                if !refreshParticipantSession(conversationId: data.conversationId, userId: participantId, retry: false) {
                    SendMessageService.shared.sendMessage(conversationId: data.conversationId, userId: participantId, sessionId: data.sessionId, action: .REFRESH_SESSION)
                }
            }
            return
        case SystemConversationAction.REMOVE.rawValue, SystemConversationAction.EXIT.rawValue:
            guard let participantId = sysMessage.participantId, !participantId.isEmpty, participantId != User.systemUser else {
                return
            }

            if participantId == currentAccountId {
                ConversationDAO.shared.exitGroup(conversationId: data.conversationId)
            } else {
                SignalProtocol.shared.clearSenderKey(groupId: data.conversationId, senderId: currentAccountId)
                operSuccess = ParticipantDAO.shared.removeParticipant(message: message,
                                                                      conversationId: data.conversationId,
                                                                      userId: participantId,
                                                                      source: data.source,
                                                                      silentNotification: data.silentNotification)
            }
            return
        case SystemConversationAction.CREATE.rawValue:
            checkUser(userId: userId, tryAgain: true)
            operSuccess = ConversationDAO.shared.updateConversationOwnerId(conversationId: data.conversationId, ownerId: userId)
        case SystemConversationAction.ROLE.rawValue:
            guard let participantId = sysMessage.participantId, !participantId.isEmpty, participantId != User.systemUser else {
                return
            }
            operSuccess = ParticipantDAO.shared.updateParticipantRole(message: message,
                                                                      conversationId: data.conversationId,
                                                                      participantId: participantId,
                                                                      role: sysMessage.role ?? "",
                                                                      source: data.source,
                                                                      silentNotification: data.silentNotification)
            return
        case SystemConversationAction.UPDATE.rawValue:
            if let participantId = sysMessage.participantId, !participantId.isEmpty, participantId != User.systemUser {
                ConcurrentJobQueue.shared.addJob(job: RefreshUserJob(userIds: [participantId]))
            } else {
                ConcurrentJobQueue.shared.addJob(job: RefreshConversationJob(conversationId: data.conversationId))
            }
            return
        default:
            break
        }

        MessageDAO.shared.insertMessage(message: message, messageSource: data.source, silentNotification: data.silentNotification)
    }
}

extension CiphertextMessage.MessageType {

    static func toString(rawValue: UInt8) -> String {
        switch rawValue {
        case CiphertextMessage.MessageType.preKey.rawValue:
            return "preKey"
        case CiphertextMessage.MessageType.senderKey.rawValue:
            return "senderKey"
        case CiphertextMessage.MessageType.signal.rawValue:
            return "signal"
        case CiphertextMessage.MessageType.distribution.rawValue:
            return "distribution"
        default:
            return "unknown"
        }
    }
}
