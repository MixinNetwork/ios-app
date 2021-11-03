import Foundation
import GRDB

public struct MessageBlaze {
    
    public let messageId: String
    public let message: Data
    public let conversationId: String
    public let createdAt: String
    
}

extension MessageBlaze: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case messageId = "_id"
        case message
        case conversationId = "conversation_id"
        case createdAt = "created_at"
    }
    
}

extension MessageBlaze: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "messages_blaze"
    
}
