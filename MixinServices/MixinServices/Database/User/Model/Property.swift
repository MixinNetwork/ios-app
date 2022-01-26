import Foundation
import GRDB

public struct Property {
    
    public let key: String
    public let value: String
    public let updatedAt: String
    
}

extension Property: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case key
        case value
        case updatedAt = "updated_at"
    }
    
}

extension Property: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "properties"
    
}
