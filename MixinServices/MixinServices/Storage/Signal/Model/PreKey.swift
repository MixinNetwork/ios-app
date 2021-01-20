import Foundation
import GRDB

struct PreKey {
    
    let preKeyId: Int
    let record: Data
    
    init(preKeyId: Int, record: Data) {
        self.preKeyId = preKeyId
        self.record = record
    }
    
}

extension PreKey: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: CodingKey {
        case preKeyId
        case record
    }
    
}

extension PreKey: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "prekeys"
    
}
