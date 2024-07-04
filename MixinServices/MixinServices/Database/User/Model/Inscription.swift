import Foundation
import GRDB

public class Inscription: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case inscriptionHash = "inscription_hash"
        case collectionHash = "collection_hash"
        case sequence
        case contentType = "content_type"
        case contentURL = "content_url"
        case occupiedBy = "occupied_by"
        case occupiedAt = "occupied_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case traits
        case owner
    }
    
    public let inscriptionHash: String
    public let collectionHash: String
    public let sequence: UInt64
    public let contentType: String
    public let contentURL: String
    public let occupiedBy: String?
    public let occupiedAt: String?
    public let createdAt: String
    public let updatedAt: String
    public let traits: String?
    public let owner: String?
    
}

extension Inscription: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "inscription_items"
    
}

extension Inscription {
    
    public static func isHashValid(_ hash: String) -> Bool {
        if let data = Data(hexEncodedString: hash) {
            return data.count == 32
        } else {
            return false
        }
    }
    
}
