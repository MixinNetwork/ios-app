import Foundation
import GRDB

public struct PriceHistoryStorage {
    
    public let coinID: String
    public let period: PriceHistoryPeriod
    public let data: String
    public let updateAt: String
    
    public init(coinID: String, period: PriceHistoryPeriod, data: String, updateAt: String) {
        self.coinID = coinID
        self.period = period
        self.data = data
        self.updateAt = updateAt
    }
    
}

extension PriceHistoryStorage: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case coinID = "coin_id"
        case period = "type"
        case data = "data"
        case updateAt = "updated_at"
    }
    
}

extension PriceHistoryStorage: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "history_prices"
    
}
