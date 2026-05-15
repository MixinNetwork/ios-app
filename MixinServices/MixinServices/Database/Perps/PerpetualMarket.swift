import Foundation
import GRDB

public struct PerpetualMarket {
    
    public enum Category: String {
        case crypto = "crypto"
        case stocks = "stocks"
        case indices = "indices"
        case commodities = "commodities"
        case forex = "forex"
    }
    
    public let marketID: String
    public let displaySymbol: String
    public let tokenSymbol: String
    public let quoteSymbol: String
    public let markPrice: String
    public let leverage: Int
    public let iconURL: String
    public let fundingRate: String
    public let minAmount: String
    public let maxAmount: String
    public let last: String
    public let volume: String
    public let high: String
    public let low: String
    public let welcomeOpen: String
    public let change: String
    public let bidPrice: String
    public let askPrice: String
    public let createdAt: String
    public let updatedAt: String
    public let category: UnknownableEnum<Category>
    public let tags: [String]
    public let priceScale: Int
    
    public var canonicalPriceFormatStyle: Decimal.FormatStyle {
        Decimal.FormatStyle.number
            .locale(.enUSPOSIX)
            .grouping(.never)
            .sign(strategy: .never)
            .rounded(rule: .towardZero)
            .precision(.fractionLength(0...priceScale))
    }
    
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
        case minAmount = "min_amount"
        case maxAmount = "max_amount"
        case last = "last"
        case volume = "volume"
        case high = "high"
        case low = "low"
        case welcomeOpen = "open"
        case change = "change"
        case bidPrice = "bid_price"
        case askPrice = "ask_price"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case category = "category"
        case tags = "tags"
        case priceScale = "price_scale"
    }
    
}

extension PerpetualMarket: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "markets"
    
}

extension PerpetualMarket {
    
    public static func userDisplayPriceFormatStyle(
        scale: Int
    ) -> Decimal.FormatStyle.Currency {
        .currency(code: "USD")
        .presentation(.narrow)
        .precision(.fractionLength(0...scale))
        .rounded(rule: .towardZero)
    }
    
}
