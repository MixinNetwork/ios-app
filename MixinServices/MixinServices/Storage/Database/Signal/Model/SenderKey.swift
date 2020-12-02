import Foundation
import GRDB

public final class SenderKey {
    
    public let groupId: String
    public let senderId: String
    public let record: Data
    
    public init(groupId: String, senderId: String, record: Data) {
        self.groupId = groupId
        self.senderId = senderId
        self.record = record
    }
    
}

extension SenderKey: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: CodingKey {
        case groupId
        case senderId
        case record
    }
    
}

extension SenderKey: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "sender_keys"
    
}
