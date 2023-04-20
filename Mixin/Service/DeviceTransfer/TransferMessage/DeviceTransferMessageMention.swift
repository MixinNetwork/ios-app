import Foundation
import MixinServices

struct DeviceTransferMessageMention {
    
    let conversationId: String
    let messageId: String
    let mentionsJson: Data?
    let hasRead: Bool
    
    init(messageMention: MessageMention) {
        conversationId = messageMention.conversationId
        messageId = messageMention.messageId
        mentionsJson = messageMention.mentionsJson
        hasRead = messageMention.hasRead
    }
    
    func toMessageMention() -> MessageMention? {
        if let mentionsJson {
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
        case mentionsJson = "mentions"
        case hasRead = "has_read"
    }
    
}
