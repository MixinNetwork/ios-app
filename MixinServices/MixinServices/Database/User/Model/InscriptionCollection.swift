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
    
    init(
        collectionHash: String, supply: String, unit: String,
        symbol: String, name: String, iconURL: String,
        createdAt: String, updatedAt: String
    ) {
        self.collectionHash = collectionHash
        self.supply = supply
        self.unit = unit
        self.symbol = symbol
        self.name = name
        self.iconURL = iconURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
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
    }
    
}

extension InscriptionCollection: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "inscription_collections"
    
}
