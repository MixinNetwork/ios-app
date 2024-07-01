import Foundation
import MixinServices

extension SendMessageService {
    
    func sendMessage(
        message: Message,
        children: [TranscriptMessage]? = nil,
        ownerUser: UserItem?,
        opponentApp: App? = nil,
        isGroupMessage: Bool,
        silentNotification: Bool = false,
        expireIn: Int64 = 0
    ) {
        guard let account = LoginManager.shared.account else {
            return
        }

        var msg = message
        msg.userId = account.userID
        msg.status = MessageStatus.SENDING.rawValue
        
        let app: App?
        if let opponentApp = opponentApp {
            app = opponentApp
        } else if let user = ownerUser, user.isBot {
            app = AppDAO.shared.getApp(ofUserId: user.userId)
        } else {
            app = nil
        }
        
        let categoryPrefix: String
        if isGroupMessage {
            if msg.category.hasSuffix("_TEXT"), let content = msg.content, let id = groupMessageRecipientAppId(content, conversationId: msg.conversationId) {
                if let app = AppDAO.shared.getApp(appId: id), app.capabilities?.contains("ENCRYPTED") ?? false {
                    categoryPrefix = "ENCRYPTED"
                } else {
                    categoryPrefix = "PLAIN"
                }
            } else {
                categoryPrefix = "SIGNAL"
            }
        } else if let user = ownerUser {
            if user.isBot {
                if let app = app, app.capabilities?.contains("ENCRYPTED") ?? false {
                    categoryPrefix = "ENCRYPTED"
                } else {
                    categoryPrefix = "PLAIN"
                }
            } else {
                categoryPrefix = "SIGNAL"
            }
        } else {
            assertionFailure("No receiver")
            categoryPrefix = "PLAIN"
        }
        
        if msg.category.hasSuffix("_TEXT") {
            msg.category = categoryPrefix + "_TEXT"
        } else if msg.category.hasSuffix("_IMAGE") {
            msg.category = categoryPrefix + "_IMAGE"
        } else if msg.category.hasSuffix("_VIDEO") {
            msg.category = categoryPrefix + "_VIDEO"
        } else if msg.category.hasSuffix("_DATA") {
            msg.category = categoryPrefix + "_DATA"
        } else if msg.category.hasSuffix("_STICKER") {
            msg.category = categoryPrefix + "_STICKER"
        } else if msg.category.hasSuffix("_CONTACT") {
            msg.category = categoryPrefix + "_CONTACT"
        } else if msg.category.hasSuffix("_AUDIO") {
            msg.category = categoryPrefix + "_AUDIO"
        } else if msg.category.hasSuffix("_LIVE") {
            msg.category = categoryPrefix + "_LIVE"
        } else if msg.category.hasSuffix("_POST") {
            msg.category = categoryPrefix + "_POST"
        } else if msg.category.hasSuffix("_LOCATION") {
            msg.category = categoryPrefix + "_LOCATION"
        } else if msg.category.hasSuffix("_TRANSCRIPT") {
            msg.category = categoryPrefix + "_TRANSCRIPT"
            let isPlainMessage = categoryPrefix == "PLAIN"
            for child in children ?? [] {
                let category = child.category
                if !isPlainMessage, category.hasPrefix("PLAIN_") {
                    let range = category.startIndex...category.index(category.startIndex, offsetBy: 4)
                    child.category.replaceSubrange(range, with: categoryPrefix)
                    if MessageCategory.allMediaCategoriesString.contains(child.category) {
                        // Force the attachment to re-upload
                        child.mediaCreatedAt = nil
                        child.content = nil
                    }
                } else if isPlainMessage, category.hasPrefix("SIGNAL_") {
                    let range = category.startIndex...category.index(category.startIndex, offsetBy: 5)
                    child.category.replaceSubrange(range, with: categoryPrefix)
                    if MessageCategory.allMediaCategoriesString.contains(child.category) {
                        // Force the attachment to re-upload
                        child.mediaCreatedAt = nil
                        child.content = nil
                    }
                } else if isPlainMessage, category.hasPrefix("ENCRYPTED_") {
                    let range = category.startIndex...category.index(category.startIndex, offsetBy: 8)
                    child.category.replaceSubrange(range, with: categoryPrefix)
                    if MessageCategory.allMediaCategoriesString.contains(child.category) {
                        // Force the attachment to re-upload
                        child.mediaCreatedAt = nil
                        child.content = nil
                    }
                }
            }
        }

        jobCreationQueue.async {
            if msg.conversationId.isEmpty || !ConversationDAO.shared.isExist(conversationId: msg.conversationId) {
                guard let user = ownerUser else {
                    return
                }
                let conversationId = ConversationDAO.shared.makeConversationId(userId: account.userID, ownerUserId: user.userId)
                msg.conversationId = conversationId
                ConversationDAO.shared.createConversation(conversation: ConversationResponse(conversationId: conversationId, userId: user.userId, avatarUrl: user.avatarUrl), targetStatus: .START)
            }
            
            if message.category.hasPrefix("WEBRTC_") {
                guard let recipient = ownerUser else {
                    Logger.call.error(category: "SendMessageService", message: "Empty recipient id")
                    return
                }
                SendMessageService.shared.sendWebRTCMessage(message: message, recipientId: recipient.userId)
            } else {
                if let content = msg.content, ["_TEXT", "_POST"].contains(where: msg.category.hasSuffix), content.utf8.count > maxTextMessageContentLength {
                    msg.content = String(content.prefix(maxTextMessageContentLength))
                }
                MessageDAO.shared.insertMessage(message: msg, children: children, messageSource: MessageDAO.LocalMessageSource.sendMessage, expireIn: expireIn) {
                    NotificationCenter.default.post(onMainThread: dismissSearchNotification, object: nil)                    
                    if ["_TEXT", "_POST", "_STICKER", "_CONTACT", "_LOCATION"].contains(where: msg.category.hasSuffix) || msg.category == MessageCategory.APP_CARD.rawValue {
                        SendMessageService.shared.sendMessage(message: msg, data: msg.content, silentNotification: silentNotification, expireIn: expireIn)
                    } else if msg.category.hasSuffix("_IMAGE") {
                        let jobId = SendMessageService.shared.saveUploadJob(message: msg)
                        UploaderQueue.shared.addJob(job: ImageUploadJob(message: msg, jobId: jobId))
                    } else if msg.category.hasSuffix("_VIDEO") {
                        let jobId = SendMessageService.shared.saveUploadJob(message: msg)
                        UploaderQueue.shared.addJob(job: VideoUploadJob(message: msg, jobId: jobId))
                    } else if msg.category.hasSuffix("_DATA") {
                        let jobId = SendMessageService.shared.saveUploadJob(message: msg)
                        UploaderQueue.shared.addJob(job: FileUploadJob(message: msg, jobId: jobId))
                    } else if msg.category.hasSuffix("_AUDIO") {
                        let jobId = SendMessageService.shared.saveUploadJob(message: msg)
                        UploaderQueue.shared.addJob(job: AudioUploadJob(message: msg, jobId: jobId))
                    } else if msg.category.hasSuffix("_TRANSCRIPT") {
                        let jobId = SendMessageService.shared.saveUploadJob(message: msg)
                        let job = TranscriptAttachmentUploadJob(message: msg, jobIdToRemoveAfterFinished: jobId)
                        UploaderQueue.shared.addJob(job: job)
                    } else if msg.category.hasSuffix("_LIVE") {
                        let data = msg.content?.base64Encoded()
                        SendMessageService.shared.sendMessage(message: msg, data: data, expireIn: expireIn)
                    }
                }
            }
        }
    }
    
}
