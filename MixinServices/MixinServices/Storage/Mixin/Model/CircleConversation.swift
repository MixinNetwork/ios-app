import Foundation
import GRDB

public final class CircleConversation {
    
    public let circleId: String
    public let conversationId: String
    public let userId: String?
    public let createdAt: String
    public let pinTime: String?
    
    public init(circleId: String, conversationId: String, userId: String?, createdAt: String, pinTime: String?) {
        self.circleId = circleId
        self.conversationId = conversationId
        self.userId = userId
        self.createdAt = createdAt
        self.pinTime = pinTime
    }
    
}

extension CircleConversation: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case circleId = "circle_id"
        case conversationId = "conversation_id"
        case userId = "user_id"
        case createdAt = "created_at"
        case pinTime = "pin_time"
        
    }
    
}

extension CircleConversation: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "circle_conversations"
    
}
