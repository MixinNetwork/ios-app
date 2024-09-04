import Foundation
import GRDB

public struct FavoredMarket {
    
    public let coinID: String
    public let isFavored: Bool
    public let createdAt: String
    
    public init(coinID: String, isFavored: Bool, createdAt: String) {
        self.coinID = coinID
        self.isFavored = isFavored
        self.createdAt = createdAt
    }
    
}

extension FavoredMarket: Codable, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case coinID = "coin_id"
        case isFavored = "is_favored"
        case createdAt = "created_at"
    }
    
}

extension FavoredMarket: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "market_favored"
    
}
