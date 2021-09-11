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

extension PinMessage {
    
    public struct LocalContent: Codable {
        
        public let category: String
        public let content: String?
        
    }
    
    public struct Banner: Codable {
        
        public let pinMessageId: String
        public let referencedMessageId: String
        
        public enum CodingKeys: String, CodingKey {
            case pinMessageId = "pid"
            case referencedMessageId = "rid"
        }
        
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
