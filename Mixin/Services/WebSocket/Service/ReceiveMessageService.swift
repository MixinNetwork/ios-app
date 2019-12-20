import Foundation
import UIKit
import SDWebImage

protocol CallMessageCoordinator: class {
    var hasActiveCall: Bool { get }
    func handleIncomingBlazeMessageData(_ data: BlazeMessageData)
}

class ReceiveMessageService: MixinService {
    
    static let shared = ReceiveMessageService()
    static let groupConversationParticipantDidChangeNotification = Notification.Name("one.mixin.messenger.group.participant.did.change")
    static let completeCallCategories: [MessageCategory] = [
        .WEBRTC_AUDIO_END,
        .WEBRTC_AUDIO_BUSY,
        .WEBRTC_AUDIO_CANCEL,
        .WEBRTC_AUDIO_FAILED,
        .WEBRTC_AUDIO_DECLINE
    ]
    
    private let processDispatchQueue = DispatchQueue(label: "one.mixin.messenger.queue.receive.messages")
    private let receiveDispatchQueue = DispatchQueue(label: "one.mixin.messenger.queue.receive")
    private let listPendingCallDelay = DispatchTimeInterval.seconds(2)
    private var listPendingCallWorkItems = [String: DispatchWorkItem]()
    private var listPendingCandidates = [String: [BlazeMessageData]]()
    
    let messageDispatchQueue = DispatchQueue(label: "one.mixin.messenger.queue.messages")
    var refreshRefreshOneTimePreKeys = [String: TimeInterval]()

    func receiveMessage(blazeMessage: BlazeMessage) {
        receiveDispatchQueue.async {
            assert(MixinService.callMessageCoordinator != nil)
            guard LoginManager.shared.isLoggedIn else {
                return
            }
            guard let data = blazeMessage.data?.data(using: .utf8), let blazeMessageData = try? self.jsonDecoder.decode(BlazeMessageData.self, from: data) else {
                return
            }
            let messageId = blazeMessageData.messageId
            let status = blazeMessageData.status

            if blazeMessage.action == BlazeMessageAction.acknowledgeMessageReceipt.rawValue {
                MessageDAO.shared.updateMessageStatus(messageId: messageId, status: status, from: blazeMessage.action)
                AppGroupUserDefaults.Crypto.Offset.status = blazeMessageData.updatedAt.toUTCDate().nanosecond()
            } else if blazeMessage.action == BlazeMessageAction.createMessage.rawValue || blazeMessage.action == BlazeMessageAction.createCall.rawValue {
                if blazeMessageData.userId == myUserId && blazeMessageData.category.isEmpty {
                    MessageDAO.shared.updateMessageStatus(messageId: messageId, status: status, from: blazeMessage.action)
                } else {
                    guard BlazeMessageDAO.shared.insertOrReplace(messageId: messageId, conversationId: blazeMessageData.conversationId, data: data, createdAt: blazeMessageData.createdAt) else {
                        return
                    }
                    ReceiveMessageService.shared.processReceiveMessages()
                }
            } else {
                ReceiveMessageService.shared.updateRemoteMessageStatus(messageId: messageId, status: .READ)
            }
        }
    }

    func processReceiveMessages() {
        guard !processing else {
            return
        }
        processing = true

        processDispatchQueue.async {
            defer {
                ReceiveMessageService.shared.processing = false
            }

            var finishedJobCount = 0

            repeat {
                let blazeMessageDatas = BlazeMessageDAO.shared.getBlazeMessageData(limit: 50)
                let remainJobCount = BlazeMessageDAO.shared.getCount()
                if remainJobCount + finishedJobCount > 500 {
                    let progress = blazeMessageDatas.count == 0 ? 100 : Int(Float(finishedJobCount) / Float(remainJobCount + finishedJobCount) * 100)
                    NotificationCenter.default.postOnMain(name: .SyncMessageDidAppear, object: progress)
                }
                guard blazeMessageDatas.count > 0 else {
                    return
                }

                for data in blazeMessageDatas {
                    guard LoginManager.shared.isLoggedIn else {
                        return
                    }
                    if MessageDAO.shared.isExist(messageId: data.messageId) || MessageHistoryDAO.shared.isExist(messageId: data.messageId) {
                        ReceiveMessageService.shared.processBadMessage(data: data)
                        continue
                    }

                    ReceiveMessageService.shared.syncConversation(data: data)
                    ReceiveMessageService.shared.checkSession(data: data)
                    if MessageCategory.isLegal(category: data.category) {
                        ReceiveMessageService.shared.processSystemMessage(data: data)
                        ReceiveMessageService.shared.processPlainMessage(data: data)
                        ReceiveMessageService.shared.processSignalMessage(data: data)
                        ReceiveMessageService.shared.processAppButton(data: data)
                        ReceiveMessageService.shared.processWebRTCMessage(data: data)
                        ReceiveMessageService.shared.processRecallMessage(data: data)
                    } else {
                        ReceiveMessageService.shared.processUnknownMessage(data: data)
                    }
                    BlazeMessageDAO.shared.delete(data: data)
                }

                finishedJobCount += blazeMessageDatas.count
            } while true
        }
    }

    private func checkSession(data: BlazeMessageData) {
        guard data.conversationId != User.systemUser && data.conversationId != currentAccountId else {
            return
        }
        let participantSession = ParticipantSessionDAO.shared.getParticipantSession(conversationId: data.conversationId, userId: data.userId, sessionId: data.sessionId)
        if participantSession == nil {
            MixinDatabase.shared.insertOrReplace(objects: [ParticipantSession(conversationId: data.conversationId, userId: data.userId, sessionId: data.sessionId, sentToServer: nil, createdAt: Date().toUTCString())])
        }
    }

    private func processUnknownMessage(data: BlazeMessageData) {
        var unknownMessage = Message.createMessage(messageId: data.messageId, category: data.category, conversationId: data.conversationId, createdAt: data.createdAt, userId: data.userId)
        unknownMessage.status = MessageStatus.UNKNOWN.rawValue
        unknownMessage.content = data.data
        MessageDAO.shared.insertMessage(message: unknownMessage, messageSource: data.source)

        ReceiveMessageService.shared.updateRemoteMessageStatus(messageId: data.messageId, status: .DELIVERED)
    }

    private func processBadMessage(data: BlazeMessageData) {
        ReceiveMessageService.shared.updateRemoteMessageStatus(messageId: data.messageId, status: .READ)
        BlazeMessageDAO.shared.delete(data: data)
    }
    
    private func processWebRTCMessage(data: BlazeMessageData) {
        guard data.category.hasPrefix("WEBRTC_") else {
            return
        }
        _ = syncUser(userId: data.getSenderId())
        updateRemoteMessageStatus(messageId: data.messageId, status: .DELIVERED)
        MessageHistoryDAO.shared.replaceMessageHistory(messageId: data.messageId)
        if data.source == BlazeMessageAction.listPendingMessages.rawValue {
            if data.category == MessageCategory.WEBRTC_AUDIO_OFFER.rawValue {
                if abs(data.createdAt.toUTCDate().timeIntervalSinceNow) >= callTimeoutInterval {
                    let msg = Message.createWebRTCMessage(data: data, category: .WEBRTC_AUDIO_CANCEL, status: .DELIVERED)
                    MessageDAO.shared.insertMessage(message: msg, messageSource: data.source)
                } else {
                    let workItem = DispatchWorkItem(block: {
                        let handler = MixinService.callMessageCoordinator.handleIncomingBlazeMessageData
                        handler(data)
                        self.listPendingCallWorkItems.removeValue(forKey: data.messageId)
                        self.listPendingCandidates[data.messageId]?.forEach(handler)
                        self.listPendingCandidates = [:]
                    })
                    listPendingCallWorkItems[data.messageId] = workItem
                    DispatchQueue.global().asyncAfter(deadline: .now() + listPendingCallDelay, execute: workItem)
                }
            } else if let workItem = listPendingCallWorkItems[data.quoteMessageId] {
                let category = MessageCategory(rawValue: data.category) ?? .WEBRTC_AUDIO_FAILED
                if category == .WEBRTC_ICE_CANDIDATE {
                    if listPendingCandidates[data.quoteMessageId] == nil {
                        listPendingCandidates[data.quoteMessageId] = [data]
                    } else {
                        listPendingCandidates[data.quoteMessageId]!.append(data)
                    }
                } else if Self.completeCallCategories.contains(category) {
                    workItem.cancel()
                    listPendingCallWorkItems.removeValue(forKey: data.quoteMessageId)
                    listPendingCandidates.removeValue(forKey: data.quoteMessageId)
                    let msg = Message.createWebRTCMessage(messageId: data.quoteMessageId,
                                                          conversationId: data.conversationId,
                                                          userId: data.userId,
                                                          category: category,
                                                          status: .DELIVERED)
                    MessageDAO.shared.insertMessage(message: msg, messageSource: data.source)
                }
            } else {
                MixinService.callMessageCoordinator.handleIncomingBlazeMessageData(data)
            }
        } else {
            MixinService.callMessageCoordinator.handleIncomingBlazeMessageData(data)
        }
    }
    
    private func processAppButton(data: BlazeMessageData) {
        guard data.category == MessageCategory.APP_BUTTON_GROUP.rawValue || data.category == MessageCategory.APP_CARD.rawValue else {
            return
        }
        let message = Message.createMessage(appMessage: data)
        MessageDAO.shared.insertMessage(message: message, messageSource: data.source)
        updateRemoteMessageStatus(messageId: data.messageId, status: .READ)
    }

    private func processRecallMessage(data: BlazeMessageData) {
        guard data.category == MessageCategory.MESSAGE_RECALL.rawValue else {
            return
        }

        updateRemoteMessageStatus(messageId: data.messageId, status: .READ)
        MessageHistoryDAO.shared.replaceMessageHistory(messageId: data.messageId)

        if let base64Data = Data(base64Encoded: data.data), let plainData = (try? jsonDecoder.decode(TransferRecallData.self, from: base64Data)), !plainData.messageId.isEmpty, let message = MessageDAO.shared.getMessage(messageId: plainData.messageId) {
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
                        self.processDecryptSuccess(data: data, plainText: plainText)
                    }
                }
            })
            let status = RatchetSenderKeyDAO.shared.getRatchetSenderKeyStatus(groupId: data.conversationId, senderId: data.userId, sessionId: data.sessionId)
            Logger.write(conversationId: data.conversationId, log: "[ProcessSignalMessage][\(username)][\(data.category)]...decrypt success...messageId:\(data.messageId)...\(data.createdAt)...status:\(status ?? "")...source:\(data.source)...resendMessageId:\(decoded.resendMessageId ?? "")...deviceId:\(SignalProtocol.convertSessionIdToDeviceId(data.sessionId))")
            if status == RatchetStatus.REQUESTING.rawValue {
                RatchetSenderKeyDAO.shared.deleteRatchetSenderKey(groupId: data.conversationId, senderId: data.userId, sessionId: data.sessionId)
                self.requestResendMessage(conversationId: data.conversationId, userId: data.userId, sessionId: data.sessionId)
            }
        } catch {
            Logger.write(conversationId: data.conversationId, log: "[ProcessSignalMessage][\(username)][\(data.category)][\(CiphertextMessage.MessageType.toString(rawValue: decoded.keyType))]...decrypt failed...\(error)...messageId:\(data.messageId)...\(data.createdAt)...source:\(data.source)...resendMessageId:\(decoded.resendMessageId ?? "")")
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
                Reporter.reportErrorToFirebase(MixinServicesError.decryptMessage(userInfo))
            }
            
            guard !MessageDAO.shared.isExist(messageId: data.messageId) else {
                Reporter.report(error: MixinServicesError.duplicatedMessage)
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

    private func refreshKeys(conversationId: String) {
        let now = Date().timeIntervalSince1970
        guard now - (refreshRefreshOneTimePreKeys[conversationId] ?? 0) > 60 else {
            return
        }
        refreshRefreshOneTimePreKeys[conversationId] = now
        Logger.write(conversationId: conversationId, log: "[ProcessSignalMessage]...refreshKeys...")
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
            Reporter.report(error: error)
        }
    }
    
    private func processDecryptSuccess(data: BlazeMessageData, plainText: String) {
        if data.category.hasSuffix("_TEXT") {
            var content = plainText
            if data.category == MessageCategory.PLAIN_TEXT.rawValue {
                guard let decoded = plainText.base64Decoded() else {
                    return
                }
                content = decoded
            }
            let message = Message.createMessage(textMessage: content, data: data)
            MessageDAO.shared.insertMessage(message: message, messageSource: data.source)
        } else if data.category.hasSuffix("_IMAGE") || data.category.hasSuffix("_VIDEO") {
            guard let base64Data = Data(base64Encoded: plainText), let transferMediaData = (try? jsonDecoder.decode(TransferAttachmentData.self, from: base64Data)) else {
                return
            }
            guard let height = transferMediaData.height, let width = transferMediaData.width, height > 0, width > 0 else {
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
                Reporter.report(error: error)
            }

            let message = Message.createMessage(mediaData: transferMediaData, data: data)
            MessageDAO.shared.insertMessage(message: message, messageSource: data.source)
        } else if data.category.hasSuffix("_LIVE") {
            guard let base64Data = Data(base64Encoded: plainText), let live = (try? jsonDecoder.decode(TransferLiveData.self, from: base64Data)) else {
                return
            }
            let message = Message.createMessage(liveData: live, data: data)
            MessageDAO.shared.insertMessage(message: message, messageSource: data.source)
        } else if data.category.hasSuffix("_DATA")  {
            guard let base64Data = Data(base64Encoded: plainText), let transferMediaData = (try? jsonDecoder.decode(TransferAttachmentData.self, from: base64Data)) else {
                return
            }
            guard transferMediaData.size > 0 else {
                return
            }
            let message = Message.createMessage(mediaData: transferMediaData, data: data)
            MessageDAO.shared.insertMessage(message: message, messageSource: data.source)
        } else if data.category.hasSuffix("_AUDIO") {
            guard let base64Data = Data(base64Encoded: plainText), let transferMediaData = (try? jsonDecoder.decode(TransferAttachmentData.self, from: base64Data)) else {
                return
            }
            let message = Message.createMessage(mediaData: transferMediaData, data: data)
            MessageDAO.shared.insertMessage(message: message, messageSource: data.source)
            let job = AudioDownloadJob(messageId: message.messageId, mediaMimeType: message.mediaMimeType)
            ConcurrentJobQueue.shared.addJob(job: job)
        } else if data.category.hasSuffix("_STICKER") {
            guard let transferStickerData = parseSticker(plainText) else {
                return
            }
            let message = Message.createMessage(stickerData: transferStickerData, data: data)
            MessageDAO.shared.insertMessage(message: message, messageSource: data.source)
        } else if data.category.hasSuffix("_CONTACT") {
            guard let base64Data = Data(base64Encoded: plainText), let transferData = (try? jsonDecoder.decode(TransferContactData.self, from: base64Data)) else {
                return
            }
            guard syncUser(userId: transferData.userId) else {
                return
            }
            let message = Message.createMessage(contactData: transferData, data: data)
            MessageDAO.shared.insertMessage(message: message, messageSource: data.source)
        }
    }

    private func insertFailedMessage(data: BlazeMessageData) {
        guard data.category == MessageCategory.SIGNAL_TEXT.rawValue || data.category == MessageCategory.SIGNAL_IMAGE.rawValue || data.category == MessageCategory.SIGNAL_DATA.rawValue || data.category == MessageCategory.SIGNAL_VIDEO.rawValue || data.category == MessageCategory.SIGNAL_LIVE.rawValue || data.category == MessageCategory.SIGNAL_AUDIO.rawValue || data.category == MessageCategory.SIGNAL_CONTACT.rawValue || data.category == MessageCategory.SIGNAL_STICKER.rawValue else {
            return
        }
        var failedMessage = Message.createMessage(messageId: data.messageId, category: data.category, conversationId: data.conversationId, createdAt: data.createdAt, userId: data.userId)
        failedMessage.status = MessageStatus.FAILED.rawValue
        failedMessage.content = data.data
        failedMessage.quoteMessageId = data.quoteMessageId.isEmpty ? nil : data.quoteMessageId
        MessageDAO.shared.insertMessage(message: failedMessage, messageSource: data.source)
    }

    private func processRedecryptMessage(data: BlazeMessageData, messageId: String, plainText: String) {
        defer {
            let quoteMessageId = data.quoteMessageId
            if !quoteMessageId.isEmpty, let quoteContent = MessageDAO.shared.getQuoteMessage(messageId: quoteMessageId) {
                MessageDAO.shared.updateMessageQuoteContent(conversationId: data.conversationId, quoteMessageId: quoteMessageId, quoteContent: quoteContent)
            }
        }
        switch data.category {
        case MessageCategory.SIGNAL_TEXT.rawValue:
            MessageDAO.shared.updateMessageContentAndStatus(content: plainText, status: Message.getStatus(data: data), messageId: messageId, category: data.category, conversationId: data.conversationId, messageSource: data.source)
        case MessageCategory.SIGNAL_IMAGE.rawValue, MessageCategory.SIGNAL_VIDEO.rawValue:
            guard let base64Data = Data(base64Encoded: plainText), let transferMediaData = (try? jsonDecoder.decode(TransferAttachmentData.self, from: base64Data)) else {
                return
            }
            guard let height = transferMediaData.height, let width = transferMediaData.width, height > 0, width > 0 else {
                return
            }
            MessageDAO.shared.updateMediaMessage(mediaData: transferMediaData, status: Message.getStatus(data: data), messageId: messageId, category: data.category, conversationId: data.conversationId, mediaStatus: .PENDING, messageSource: data.source)
        case MessageCategory.SIGNAL_DATA.rawValue:
            guard let base64Data = Data(base64Encoded: plainText), let transferMediaData = (try? jsonDecoder.decode(TransferAttachmentData.self, from: base64Data)) else {
                return
            }
            guard transferMediaData.size > 0 else {
                return
            }
            MessageDAO.shared.updateMediaMessage(mediaData: transferMediaData, status: Message.getStatus(data: data), messageId: messageId, category: data.category, conversationId: data.conversationId, mediaStatus: .PENDING, messageSource: data.source)
        case MessageCategory.SIGNAL_AUDIO.rawValue:
            guard let base64Data = Data(base64Encoded: plainText), let transferMediaData = (try? jsonDecoder.decode(TransferAttachmentData.self, from: base64Data)) else {
                return
            }
            MessageDAO.shared.updateMediaMessage(mediaData: transferMediaData, status: Message.getStatus(data: data), messageId: messageId, category: data.category, conversationId: data.conversationId, mediaStatus: .PENDING, messageSource: data.source)
            let job = AudioDownloadJob(messageId: messageId, mediaMimeType: transferMediaData.mimeType)
            ConcurrentJobQueue.shared.addJob(job: job)
        case MessageCategory.SIGNAL_LIVE.rawValue:
            guard let base64Data = Data(base64Encoded: plainText), let liveData = (try? jsonDecoder.decode(TransferLiveData.self, from: base64Data)) else {
                return
            }
            MessageDAO.shared.updateLiveMessage(liveData: liveData, status:  Message.getStatus(data: data), messageId: messageId, category: data.category, conversationId: data.conversationId, messageSource: data.source)
        case MessageCategory.SIGNAL_STICKER.rawValue:
            guard let transferStickerData = parseSticker(plainText) else {
                return
            }
            MessageDAO.shared.updateStickerMessage(stickerData: transferStickerData, status: Message.getStatus(data: data), messageId: messageId, category: data.category, conversationId: data.conversationId, messageSource: data.source)
        case MessageCategory.SIGNAL_CONTACT.rawValue:
            guard let base64Data = Data(base64Encoded: plainText), let transferData = (try? jsonDecoder.decode(TransferContactData.self, from: base64Data)) else {
                return
            }
            guard syncUser(userId: transferData.userId) else {
                return
            }
            MessageDAO.shared.updateContactMessage(transferData: transferData, status: Message.getStatus(data: data), messageId: messageId, category: data.category, conversationId: data.conversationId, messageSource: data.source)
        default:
            break
        }
    }

    private func parseSticker(_ stickerText: String) -> TransferStickerData? {
        guard let base64Data = Data(base64Encoded: stickerText), let transferStickerData = (try? jsonDecoder.decode(TransferStickerData.self, from: base64Data)) else {
            return nil
        }

        if let stickerId = transferStickerData.stickerId, !stickerId.isEmpty {
            guard !StickerDAO.shared.isExist(stickerId: stickerId) else {
                return transferStickerData
            }

            repeat {
                switch StickerAPI.shared.sticker(stickerId: stickerId) {
                case let .success(sticker):
                    StickerDAO.shared.insertOrUpdateSticker(sticker: sticker)
                    if let sticker = StickerDAO.shared.getSticker(stickerId: sticker.stickerId) {
                        StickerPrefetcher.prefetch(stickers: [sticker])
                    }
                    return transferStickerData
                case let .failure(error):
                    guard error.code != 404 else {
                        return nil
                    }
                    checkNetworkAndWebSocket()
                }
            } while LoginManager.shared.isLoggedIn
            return nil
        } else if let stickerName = transferStickerData.name, let albumId = transferStickerData.albumId, let sticker = StickerDAO.shared.getSticker(albumId: albumId, name: stickerName) {
            return TransferStickerData(stickerId: sticker.stickerId, name: nil, albumId: nil)
        }
        return nil
    }

    private func syncConversation(data: BlazeMessageData) {
        guard data.conversationId != User.systemUser && data.conversationId != myUserId else {
            return
        }
        if let status = ConversationDAO.shared.getConversationStatus(conversationId: data.conversationId) {
            if status == ConversationStatus.SUCCESS.rawValue || status == ConversationStatus.QUIT.rawValue {
                return
            } else if status == ConversationStatus.START.rawValue && ConversationDAO.shared.getConversationCategory(conversationId: data.conversationId) == ConversationCategory.GROUP.rawValue {
                // from NewGroupViewController
                return
            }
        } else {
            switch ConversationAPI.shared.getConversation(conversationId: data.conversationId) {
            case let .success(response):
                let userIds = response.participants
                    .map{ $0.userId }
                    .filter{ $0 != currentAccountId }
                var updatedUsers = true
                if userIds.count > 0 {
                    switch UserAPI.shared.showUsers(userIds: userIds) {
                    case let .success(users):
                        UserDAO.shared.updateUsers(users: users)
                    case .failure:
                        updatedUsers = false
                    }
                }
                if !ConversationDAO.shared.createConversation(conversation: response, targetStatus: .SUCCESS) || !updatedUsers {
                    ConcurrentJobQueue.shared.addJob(job: RefreshConversationJob(conversationId: data.conversationId))
                }
                return
            case .failure:
                ConversationDAO.shared.createPlaceConversation(conversationId: data.conversationId, ownerId: data.userId)
            }
        }
        ConcurrentJobQueue.shared.addJob(job: RefreshConversationJob(conversationId: data.conversationId))
    }

    @discardableResult
    private func checkUser(userId: String, tryAgain: Bool = false) -> ParticipantStatus {
        guard !userId.isEmpty else {
            return .ERROR
        }
        guard User.systemUser != userId, userId != currentAccountId, !UserDAO.shared.isExist(userId: userId) else {
            return .SUCCESS
        }
        switch UserAPI.shared.showUser(userId: userId) {
        case let .success(response):
            UserDAO.shared.updateUsers(users: [response])
            return .SUCCESS
        case let .failure(error):
            if tryAgain && error.code != 404 {
                ConcurrentJobQueue.shared.addJob(job: RefreshUserJob(userIds: [userId]))
            }
            return error.code == 404 ? .ERROR : .START
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
            switch UserAPI.shared.showUser(userId: userId) {
            case let .success(response):
                UserDAO.shared.updateUsers(users: [response])
                return true
            case let .failure(error):
                guard error.code != 404 else {
                    return false
                }
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
            guard let base64Data = Data(base64Encoded: data.data), let plainData = (try? jsonDecoder.decode(PlainJsonMessagePayload.self, from: base64Data)) else {
                return
            }

            if let user = UserDAO.shared.getUser(userId: data.userId) {
                Logger.write(conversationId: data.conversationId, log: "[ProcessPlainMessage][\(user.fullName)][\(data.category)][\(plainData.action)]...messageId:\(data.messageId)...\(data.createdAt)")
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
                let messageIds = ackMessages.map({ $0.messageId })
                UNUserNotificationCenter.current().removeNotifications(withIdentifiers: messageIds)
                for message in ackMessages {
                    guard message.status == MessageStatus.READ.rawValue else {
                        continue
                    }
                    if MessageDAO.shared.updateMessageStatus(messageId: message.messageId, status: MessageStatus.READ.rawValue, from: "\(data.category):\(plainData.action)", updateUnseen: true) {
                        ReceiveMessageService.shared.updateRemoteMessageStatus(messageId: message.messageId, status: .READ)
                    }
                }
                NotificationCenter.default.post(name: MixinService.messageReadStatusDidChangeNotification, object: self)
            default:
                break
            }
        case MessageCategory.PLAIN_TEXT.rawValue, MessageCategory.PLAIN_IMAGE.rawValue, MessageCategory.PLAIN_DATA.rawValue, MessageCategory.PLAIN_VIDEO.rawValue, MessageCategory.PLAIN_LIVE.rawValue, MessageCategory.PLAIN_AUDIO.rawValue, MessageCategory.PLAIN_STICKER.rawValue, MessageCategory.PLAIN_CONTACT.rawValue:
            _ = syncUser(userId: data.getSenderId())
            processDecryptSuccess(data: data, plainText: data.data)
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

        Logger.write(conversationId: conversationId, log: "[ReceiveMessageService][REQUEST_REQUEST_MESSAGES]...messages:[\(messages.joined(separator: ","))]")
        let transferPlainData = PlainJsonMessagePayload(action: PlainDataAction.RESEND_MESSAGES.rawValue, messageId: nil, messages: messages, ackMessages: nil)
        let encoded = (try? jsonEncoder.encode(transferPlainData).base64EncodedString()) ?? ""
        let messageId = UUID().uuidString.lowercased()
        let params = BlazeMessageParam(conversationId: conversationId, recipientId: userId, category: MessageCategory.PLAIN_JSON.rawValue, data: encoded, status: MessageStatus.SENDING.rawValue, messageId: messageId, sessionId: sessionId)
        let blazeMessage = BlazeMessage(params: params, action: BlazeMessageAction.createMessage.rawValue)
        SendMessageService.shared.sendMessage(conversationId: conversationId, userId: userId, blazeMessage: blazeMessage, action: .REQUEST_RESEND_MESSAGES)
    }

    private func requestResendKey(conversationId: String, recipientId: String, messageId: String, sessionId: String?) {
        let transferPlainData = PlainJsonMessagePayload(action: PlainDataAction.RESEND_KEY.rawValue, messageId: messageId, messages: nil, ackMessages: nil)
        let encoded = (try? jsonEncoder.encode(transferPlainData).base64EncodedString()) ?? ""
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
        default:
            break
        }
        updateRemoteMessageStatus(messageId: data.messageId, status: .READ)
    }

    private func processSystemSnapshotMessage(data: BlazeMessageData) {
        guard let base64Data = Data(base64Encoded: data.data), let snapshot = (try? jsonDecoder.decode(Snapshot.self, from: base64Data)) else {
            return
        }

        if let opponentId = snapshot.opponentId {
            checkUser(userId: opponentId, tryAgain: true)
        }

        switch AssetAPI.shared.asset(assetId: snapshot.assetId) {
        case let .success(asset):
            AssetDAO.shared.insertOrUpdateAssets(assets: [asset])
        case .failure:
            ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob(assetId: snapshot.assetId))
        }

        if snapshot.type == SnapshotType.deposit.rawValue, let transactionHash = snapshot.transactionHash {
            SnapshotDAO.shared.removePendingDeposits(assetId: snapshot.assetId, transactionHash: transactionHash)
        }

        SnapshotDAO.shared.insertOrReplaceSnapshots(snapshots: [snapshot])
        let message = Message.createMessage(snapshotMesssage: snapshot, data: data)
        MessageDAO.shared.insertMessage(message: message, messageSource: data.source)
    }

    private func processSystemSessionMessage(data: BlazeMessageData) {
        guard let base64Data = Data(base64Encoded: data.data), let systemSession = (try? jsonDecoder.decode(SystemSessionMessagePayload.self, from: base64Data)) else {
            return
        }

        if systemSession.action == SystemSessionMessageAction.PROVISION.rawValue {
            AppGroupUserDefaults.Account.lastDesktopLoginDate = Date()
            AppGroupUserDefaults.Account.extensionSession = systemSession.sessionId
            SignalProtocol.shared.deleteSession(userId: data.userId)

            ParticipantSessionDAO.shared.provisionSession(userId: systemSession.userId, sessionId: systemSession.sessionId)
            NotificationCenter.default.postOnMain(name: .UserSessionDidChange)
        } else if (systemSession.action == SystemSessionMessageAction.DESTROY.rawValue) {
            AppGroupUserDefaults.Account.extensionSession = nil
            SignalProtocol.shared.deleteSession(userId: data.userId)

            JobDAO.shared.clearSessionJob()
            ParticipantSessionDAO.shared.destorySession(userId: systemSession.userId, sessionId: systemSession.sessionId)
            NotificationCenter.default.postOnMain(name: .UserSessionDidChange)
        }
    }

    private func processSystemConversationMessage(data: BlazeMessageData) {
        guard let base64Data = Data(base64Encoded: data.data), let sysMessage = (try? jsonDecoder.decode(SystemConversationMessagePayload.self, from: base64Data)) else {
            return
        }

        let userId = sysMessage.userId ?? data.userId
        let messageId = data.messageId
        var operSuccess = true

        if let participantId = sysMessage.participantId {
            let usernameOrId = UserDAO.shared.getUser(userId: participantId)?.fullName ?? participantId
            Logger.write(conversationId: data.conversationId, log: "[ProcessSystemMessage][\(usernameOrId)][\(sysMessage.action)]...messageId:\(data.messageId)...\(data.createdAt)")
        }

        if (userId == User.systemUser) {
            UserDAO.shared.insertSystemUser(userId: userId)
        }

        let message = Message.createMessage(systemMessage: sysMessage.action, participantId: sysMessage.participantId, userId: userId, data: data)

        defer {
            let participantDidChange = operSuccess
                && sysMessage.action != SystemConversationAction.UPDATE.rawValue
                && sysMessage.action != SystemConversationAction.ROLE.rawValue
            let userInfo = [MixinService.UserInfoKey.conversationId: data.conversationId]
            NotificationCenter.default.post(name: Self.groupConversationParticipantDidChangeNotification, object: self, userInfo: userInfo)
        }
        
        switch sysMessage.action {
        case SystemConversationAction.ADD.rawValue, SystemConversationAction.JOIN.rawValue:
            guard let participantId = sysMessage.participantId, !participantId.isEmpty, participantId != User.systemUser else {
                return
            }
            let status = checkUser(userId: participantId, tryAgain: true)
            operSuccess = ParticipantDAO.shared.addParticipant(message: message, conversationId: data.conversationId, participantId: participantId, updatedAt: data.updatedAt, status: status, source: data.source)

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
                DispatchQueue.global().async {
                    ConversationDAO.shared.deleteAndExitConversation(conversationId: data.conversationId, autoNotification: false)
                }
            } else {
                SignalProtocol.shared.clearSenderKey(groupId: data.conversationId, senderId: currentAccountId)
                operSuccess = ParticipantDAO.shared.removeParticipant(message: message, conversationId: data.conversationId, userId: participantId, source: data.source)
            }
            return
        case SystemConversationAction.CREATE.rawValue:
            checkUser(userId: userId, tryAgain: true)
            operSuccess = ConversationDAO.shared.updateConversationOwnerId(conversationId: data.conversationId, ownerId: userId)
        case SystemConversationAction.ROLE.rawValue:
            guard let participantId = sysMessage.participantId, !participantId.isEmpty, participantId != User.systemUser, let role = sysMessage.role else {
                return
            }
            operSuccess = ParticipantDAO.shared.updateParticipantRole(message: message, conversationId: data.conversationId, participantId: participantId, role: role, source: data.source)
            return
        case SystemConversationAction.UPDATE.rawValue:
            ConcurrentJobQueue.shared.addJob(job: RefreshConversationJob(conversationId: data.conversationId))
            return
        default:
            break
        }

        MessageDAO.shared.insertMessage(message: message, messageSource: data.source)
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
