import Foundation
import GRDB

enum RatchetStatus: String {
    case REQUESTING
}

struct RatchetSenderKey {
    
    let groupId: String
    let senderId: String
    let status: String
    
}

extension RatchetSenderKey: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: CodingKey {
        case groupId
        case senderId
        case status
    }
    
}

extension RatchetSenderKey: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "ratchet_sender_keys"
    
}
