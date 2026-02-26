import Foundation
import GRDB

public struct PerpetualMarket {
    
    public let marketID: String
    public let id: Int
    public let market: String
    public let symbol: String
    public let displaySymbol: String
    public let tokenSymbol: String
    public let feeMode: Int
    public let markMethod: String
    public let markPrice: String
    public let makerFee: String
    public let takerFee: String
    public let baseInterest: String
    public let quoteInterest: String
    public let fundingRate: String
    public let predictedFundingRate: String
    public let nextFundingTime: Int
    public let prevFundingTime: Int
    public let quantityScale: Int
    public let priceScale: Int
    public let minOrderSize: String
    public let maxOrderSize: String
    public let minOrderValue: String
    public let maxOrderValue: String
    public let quantityIncrement: String
    public let priceIncrement: String
    public let profitSharing: String
    public let mini: Int
    public let time: Int
    public let leverage: Int
    public let iconURL: String
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
        case id = "id"
        case market = "market"
        case symbol = "symbol"
        case displaySymbol = "display_symbol"
        case tokenSymbol = "token_symbol"
        case feeMode = "fee_mode"
        case markMethod = "mark_method"
        case markPrice = "mark_price"
        case makerFee = "maker_fee"
        case takerFee = "taker_fee"
        case baseInterest = "base_interest"
        case quoteInterest = "quote_interest"
        case fundingRate = "funding_rate"
        case predictedFundingRate = "predicted_funding_rate"
        case nextFundingTime = "next_funding_time"
        case prevFundingTime = "prev_funding_time"
        case quantityScale = "quantity_scale"
        case priceScale = "price_scale"
        case minOrderSize = "min_order_size"
        case maxOrderSize = "max_order_size"
        case minOrderValue = "min_order_value"
        case maxOrderValue = "max_order_value"
        case quantityIncrement = "quantity_increment"
        case priceIncrement = "price_increment"
        case profitSharing = "profit_sharing"
        case mini = "mini"
        case time = "time"
        case leverage = "leverage"
        case iconURL = "icon_url"
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
