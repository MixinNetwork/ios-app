import Foundation
import GRDB

public final class PinMessage {
    
    public let messageId: String
    public let conversationId: String
    public let createdAt: String
    
    public init(messageId: String, conversationId: String, createdAt: String) {
        self.messageId = messageId
        self.conversationId = conversationId
        self.createdAt = createdAt
    }
    
}

extension PinMessage: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case conversationId = "conversation_id"
        case createdAt = "created_at"
    }
    
}

extension PinMessage: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "pin_messages"
    
}
