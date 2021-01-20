import Foundation
import GRDB

struct MessageBlaze {
    
    public let messageId: String
    public let message: Data
    public let createdAt: String
    
}

extension MessageBlaze: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    enum CodingKeys: String, CodingKey {
        case messageId = "_id"
        case message
        case createdAt = "created_at"
    }
    
}

extension MessageBlaze: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "messages_blaze"
    
}
