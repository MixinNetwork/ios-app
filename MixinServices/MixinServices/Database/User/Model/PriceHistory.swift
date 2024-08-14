import Foundation
import GRDB

public struct PriceHistory {
    
    public enum Period: String, CaseIterable, Equatable, Codable {
        case day = "1D"
        case week = "1W"
        case month = "1M"
        case year = "YTD"
        case all = "ALL"
    }
    
    public let assetID: String
    public let period: Period
    public let data: String
    public let updateAt: String
    
    public init(assetID: String, period: Period, data: String, updateAt: String) {
        self.assetID = assetID
        self.period = period
        self.data = data
        self.updateAt = updateAt
    }
    
}

extension PriceHistory: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case assetID = "asset_id"
        case period = "type"
        case data = "data"
        case updateAt = "updated_at"
    }
    
}

extension PriceHistory: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "history_prices"
    
}
