import Foundation
import GRDB

struct SignedPreKey {
    
    let preKeyId: Int
    let record: Data
    let timestamp: TimeInterval
    
    init(preKeyId: Int, record: Data, timestamp: TimeInterval) {
        self.preKeyId = preKeyId
        self.record = record
        self.timestamp = timestamp
    }
    
}

extension SignedPreKey: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: CodingKey {
        case preKeyId
        case record
        case timestamp
    }
    
}

extension SignedPreKey: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "signed_prekeys"
    
}
