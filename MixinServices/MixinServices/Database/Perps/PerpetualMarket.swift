import Foundation
import GRDB

public struct PerpetualMarket {
    
    public let marketID: String
    public let displaySymbol: String
    public let tokenSymbol: String
    public let quoteSymbol: String
    public let markPrice: String
    public let leverage: Int
    public let iconURL: String
    public let fundingRate: String
    public let minOrderSize: String
    public let maxOrderSize: String
    public let minOrderValue: String
    public let maxOrderValue: String
    public let last: String
    public let volume: String
    public let amount: String
    public let high: String
    public let low: String
    public let welcomeOpen: String
    public let change: String
    public let bidPrice: String
    public let askPrice: String
    public let tradeCount: Int
    public let firstTradeID: Int
    public let createdAt: String
    public let updatedAt: String
    
}

extension PerpetualMarket: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case marketID = "market_id"
        case displaySymbol = "display_symbol"
        case tokenSymbol = "token_symbol"
        case quoteSymbol = "quote_symbol"
        case markPrice = "mark_price"
        case leverage = "leverage"
        case iconURL = "icon_url"
        case fundingRate = "funding_rate"
        case minOrderSize = "min_order_size"
        case maxOrderSize = "max_order_size"
        case minOrderValue = "min_order_value"
        case maxOrderValue = "max_order_value"
        case last = "last"
        case volume = "volume"
        case amount = "amount"
        case high = "high"
        case low = "low"
        case welcomeOpen = "open"
        case change = "change"
        case bidPrice = "bid_price"
        case askPrice = "ask_price"
        case tradeCount = "trade_count"
        case firstTradeID = "first_trade_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
}

extension PerpetualMarket: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "markets"
    
}
