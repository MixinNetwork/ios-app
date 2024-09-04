import Foundation
import GRDB

struct MarketID {
    
    let coinID: String
    let assetID: String
    let createdAt: String
    
}

extension MarketID: Encodable, MixinEncodableRecord {
    
    enum CodingKeys: String, CodingKey {
        case coinID = "coin_id"
        case assetID = "asset_id"
        case createdAt = "created_at"
    }
    
}

extension MarketID: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "market_ids"
    
}
