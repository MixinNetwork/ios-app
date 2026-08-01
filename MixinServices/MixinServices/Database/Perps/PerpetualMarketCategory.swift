import Foundation
import GRDB

struct PerpetualMarketCategory {
    
    let marketID: String
    let category: Int
    
    init(marketID: String, category: Market.DatabaseCategory) {
        self.marketID = marketID
        self.category = category.rawValue
    }
    
}

extension PerpetualMarketCategory: Encodable, DatabaseColumnConvertible, MixinEncodableRecord {
    
    enum CodingKeys: String, CodingKey {
        case marketID = "market_id"
        case category = "category"
    }
    
}

extension PerpetualMarketCategory: PersistableRecord {
    
    public static let databaseTableName = "market_categories"
    
}
