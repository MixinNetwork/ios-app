import Foundation
import MixinServices

extension SendMessageService {
    
    @objc func uploadAnyPendingMessages() {
        let messages = MessageDAO.shared.getPendingMessages()
        for message in messages {
            guard message.shouldUpload() else {
                continue
            }
            if message.category.hasSuffix("_IMAGE") {
                UploaderQueue.shared.addJob(job: ImageUploadJob(message: message))
            } else if message.category.hasSuffix("_DATA") {
                UploaderQueue.shared.addJob(job: FileUploadJob(message: message))
            } else if message.category.hasSuffix("_VIDEO") {
                UploaderQueue.shared.addJob(job: VideoUploadJob(message: message))
            } else if message.category.hasSuffix("_AUDIO") {
                UploaderQueue.shared.addJob(job: AudioUploadJob(message: message))
            }
        }
    }
    
    func sendMessage(message: Message, ownerUser: UserItem?, isGroupMessage: Bool) {
        guard let account = LoginManager.shared.account else {
            return
        }

        var msg = message
        msg.userId = account.user_id
        msg.status = MessageStatus.SENDING.rawValue

        var isSignalMessage = isGroupMessage
        if !isGroupMessage {
            isSignalMessage = !(ownerUser?.isBot ?? true)
        }

        if msg.category.hasSuffix("_TEXT") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_TEXT.rawValue :  MessageCategory.PLAIN_TEXT.rawValue
        } else if msg.category.hasSuffix("_IMAGE") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_IMAGE.rawValue :  MessageCategory.PLAIN_IMAGE.rawValue
        } else if msg.category.hasSuffix("_VIDEO") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_VIDEO.rawValue :  MessageCategory.PLAIN_VIDEO.rawValue
        } else if msg.category.hasSuffix("_DATA") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_DATA.rawValue :  MessageCategory.PLAIN_DATA.rawValue
        } else if msg.category.hasSuffix("_STICKER") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_STICKER.rawValue :  MessageCategory.PLAIN_STICKER.rawValue
        } else if msg.category.hasSuffix("_CONTACT") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_CONTACT.rawValue :  MessageCategory.PLAIN_CONTACT.rawValue
        } else if msg.category.hasSuffix("_AUDIO") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_AUDIO.rawValue :  MessageCategory.PLAIN_AUDIO.rawValue
        } else if msg.category.hasSuffix("_LIVE") {
            msg.category = isSignalMessage ? MessageCategory.SIGNAL_LIVE.rawValue :  MessageCategory.PLAIN_LIVE.rawValue
        }

        if msg.conversationId.isEmpty || !ConversationDAO.shared.isExist(conversationId: msg.conversationId) {
            guard let user = ownerUser else {
                return
            }
            let conversationId = ConversationDAO.shared.makeConversationId(userId: account.user_id, ownerUserId: user.userId)
            msg.conversationId = conversationId

            let createdAt = Date().toUTCString()
            let participants = [ParticipantResponse(userId: user.userId, role: ParticipantRole.OWNER.rawValue, createdAt: createdAt), ParticipantResponse(userId: account.user_id, role: "", createdAt: createdAt)]
            let response = ConversationResponse(conversationId: conversationId, name: "", category: ConversationCategory.CONTACT.rawValue, iconUrl: user.avatarUrl, announcement: "", createdAt: Date().toUTCString(), participants: participants, participantSessions: nil, codeUrl: "", creatorId: user.userId, muteUntil: "")
            ConversationDAO.shared.createConversation(conversation: response, targetStatus: .START)
        }
        if !message.category.hasPrefix("WEBRTC_") {
            MessageDAO.shared.insertMessage(message: msg, messageSource: "")
        }
        if msg.category.hasSuffix("_TEXT") || msg.category.hasSuffix("_STICKER") || message.category.hasSuffix("_CONTACT") || message.category.hasSuffix("_LIVE") {
            SendMessageService.shared.sendMessage(message: msg, data: message.content)
        } else if msg.category.hasSuffix("_IMAGE") {
            UploaderQueue.shared.addJob(job: ImageUploadJob(message: msg))
        } else if msg.category.hasSuffix("_VIDEO") {
            UploaderQueue.shared.addJob(job: VideoUploadJob(message: msg))
        } else if msg.category.hasSuffix("_DATA") {
            UploaderQueue.shared.addJob(job: FileUploadJob(message: msg))
        } else if msg.category.hasSuffix("_AUDIO") {
            UploaderQueue.shared.addJob(job: AudioUploadJob(message: msg))
        } else if message.category.hasPrefix("WEBRTC_"), let recipient = ownerUser {
            SendMessageService.shared.sendWebRTCMessage(message: message, recipientId: recipient.userId)
        }
    }
    
}
