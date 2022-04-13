import Foundation
import GRDB

public final class DisappearingMessage {
    
    public let messageId: String
    public let expireIn: Int64
    public var expireAt: Int64
    
    public init(messageId: String, expireIn: Int64, expireAt: Int64? = nil) {
        self.messageId = messageId
        self.expireIn = expireIn
        if let expireAt = expireAt {
            self.expireAt = expireAt
        } else {
            if expireIn > 60 * 60 * 24 {
                // If a message is set to be expired after more than 24hrs, it will be deleted on time despite reading status
                self.expireAt = Int64(Date().addingTimeInterval(TimeInterval(expireIn)).timeIntervalSince1970)
            } else {
                self.expireAt = 0
            }
        }
    }
    
}

extension DisappearingMessage: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case expireIn = "expire_in"
        case expireAt = "expire_at"
    }
    
}

extension DisappearingMessage: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "disappearing_messages"
    
}
