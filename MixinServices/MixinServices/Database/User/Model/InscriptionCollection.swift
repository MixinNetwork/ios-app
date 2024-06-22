import Foundation
import GRDB

public struct InscriptionCollection {
    
    public let collectionHash: String
    public let supply: String
    public let unit: String
    public let symbol: String
    public let name: String
    public let iconURL: String
    public let createdAt: String
    public let updatedAt: String
    public let description: String?
    
}

extension InscriptionCollection: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case collectionHash = "collection_hash"
        case supply
        case unit
        case symbol
        case name
        case iconURL = "icon_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case description
    }
    
}

extension InscriptionCollection: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "inscription_collections"
    
}
