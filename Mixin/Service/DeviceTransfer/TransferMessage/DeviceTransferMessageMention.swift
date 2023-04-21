import Foundation
import MixinServices

struct DeviceTransferMessageMention {
    
    let conversationId: String
    let messageId: String
    let mentions: String?
    let hasRead: Bool
    
    init(messageMention: MessageMention) {
        conversationId = messageMention.conversationId
        messageId = messageMention.messageId
        mentions = String(data: messageMention.mentionsJson, encoding: .utf8)
        hasRead = messageMention.hasRead
    }
    
    func toMessageMention() -> MessageMention? {
        if let mentions, let mentionsJson = mentions.data(using: .utf8) {
            return MessageMention(conversationId: conversationId,
                                  messageId: messageId,
                                  mentionsJson: mentionsJson,
                                  hasRead: hasRead)
        } else if let content = MessageDAO.shared.messageContent(conversationId: conversationId, messageId: messageId) {
            return MessageMention(conversationId: conversationId,
                                  messageId: messageId,
                                  content: content,
                                  addMeIntoMentions: false,
                                  hasRead: { _ in hasRead })
        } else {
            return nil
        }
    }
    
}

extension DeviceTransferMessageMention: Codable {
    
    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case conversationId = "conversation_id"
        case mentions
        case hasRead = "has_read"
    }
    
}
