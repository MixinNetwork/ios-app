import Foundation
import GRDB

struct MessageHistory {
    
    public let messageId: String
    
}

extension MessageHistory: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
    }
    
}

extension MessageHistory: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "messages_history"
    
}
