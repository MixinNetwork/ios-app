import Foundation
import GRDB

struct MarketCapRank {
    
    let coinID: String
    let marketCapRank: String
    let updatedAt: String

}

extension MarketCapRank: Codable, MixinFetchableRecord, MixinEncodableRecord {
    
    enum CodingKeys: String, CodingKey {
        case coinID = "coin_id"
        case marketCapRank = "market_cap_rank"
        case updatedAt = "updated_at"
    }
    
}

extension MarketCapRank: PersistableRecord {
    
    static let databaseTableName = "market_cap_ranks"
    
}
