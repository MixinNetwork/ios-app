import Foundation
import GRDB

struct ResendSessionMessage {
    
    public let messageId: String
    public let userId: String
    public let sessionId: String
    public let status: Int
    
}

extension ResendSessionMessage: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {

    public enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case userId = "user_id"
        case sessionId = "session_id"
        case status
    }
    
}

extension ResendSessionMessage: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "resend_session_messages"
    
}
