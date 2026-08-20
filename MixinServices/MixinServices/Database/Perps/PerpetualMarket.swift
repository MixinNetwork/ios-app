import Foundation
import GRDB

public class PerpetualMarket: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
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
        case openPrice = "open"
        case change = "change"
        case bidPrice = "bid_price"
        case askPrice = "ask_price"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case category = "category"
        case tags = "tags"
        case priceScale = "price_scale"
        case descriptions = "descriptions"
        case fundingIntervalHours = "funding_interval_hours"
        case nextFundingAt = "next_funding_at"
        case openInterest = "open_interest"
        case tradeVolumeScore1D = "trade_volume_score_1d"
    }
    
    public enum Category: String, CaseIterable {
        case crypto = "crypto"
        case stocks = "stocks"
        case indices = "indices"
        case commodities = "commodities"
        case forex = "forex"
        case memes = "memes"
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
    public let openPrice: String
    public let change: String
    public let bidPrice: String
    public let askPrice: String
    public let createdAt: String
    public let updatedAt: String
    public let category: UnknownableEnum<Category>
    public let tags: [String]
    public let priceScale: Int
    public let descriptions: [String: String]?
    public let fundingIntervalHours: Int
    public let nextFundingAt: String
    public let openInterest: String
    public let tradeVolumeScore1D: Int
    
    public var canonicalPriceFormatStyle: Decimal.FormatStyle {
        Decimal.FormatStyle.number
            .locale(.enUSPOSIX)
            .grouping(.never)
            .sign(strategy: .never)
            .rounded(rule: .towardZero)
            .precision(.fractionLength(0...priceScale))
    }
    
    public private(set) lazy var decimalPrice = Decimal(string: last, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var localizedPrice = decimalPrice.formatted(
        PerpetualMarket.userDisplayPriceFormatStyle(scale: priceScale)
    )
    
    public private(set) lazy var decimalVolume = Decimal(string: volume, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var prettyVolume = NamedLargeNumberFormatter.string(number: decimalVolume, currency: .usd)
    
    public private(set) lazy var decimalChange = Decimal(string: change, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var changePercentage = NumberFormatter.percentage.string(decimal: decimalChange) ?? "-%"
    
    init(
        marketID: String,
        displaySymbol: String,
        tokenSymbol: String,
        quoteSymbol: String,
        markPrice: String,
        leverage: Int,
        iconURL: String,
        fundingRate: String,
        minAmount: String,
        maxAmount: String,
        last: String,
        volume: String,
        high: String,
        low: String,
        openPrice: String,
        change: String,
        bidPrice: String,
        askPrice: String,
        createdAt: String,
        updatedAt: String,
        category: UnknownableEnum<PerpetualMarket.Category>,
        tags: [String],
        priceScale: Int,
        descriptions: [String : String]?,
        fundingIntervalHours: Int,
        nextFundingAt: String,
        openInterest: String,
        tradeVolumeScore1D: Int,
    ) {
        self.marketID = marketID
        self.displaySymbol = displaySymbol
        self.tokenSymbol = tokenSymbol
        self.quoteSymbol = quoteSymbol
        self.markPrice = markPrice
        self.leverage = leverage
        self.iconURL = iconURL
        self.fundingRate = fundingRate
        self.minAmount = minAmount
        self.maxAmount = maxAmount
        self.last = last
        self.volume = volume
        self.high = high
        self.low = low
        self.openPrice = openPrice
        self.change = change
        self.bidPrice = bidPrice
        self.askPrice = askPrice
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.category = category
        self.tags = tags
        self.priceScale = priceScale
        self.descriptions = descriptions
        self.fundingIntervalHours = fundingIntervalHours
        self.nextFundingAt = nextFundingAt
        self.openInterest = openInterest
        self.tradeVolumeScore1D = tradeVolumeScore1D
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

extension PerpetualMarket {
    
    public enum QueryCategory {
        case watchlist
        case all
        case categorized(Category)
    }
    
    public enum RequestCategory: String, CaseIterable {
        case all
        case favorite
        case featured
    }
    
}

extension PerpetualMarket {
    
    struct FavoriteStorage: Codable, MixinEncodableRecord, PersistableRecord {
        
        enum CodingKeys: String, CodingKey {
            case marketID = "market_id"
            case isFavorite = "is_favored"
            case createdAt = "created_at"
        }
        
        static let databaseTableName = "favorites"
        
        let marketID: String
        let isFavorite: Bool
        let createdAt: String
        
    }
    
}

extension PerpetualMarket {
    
    public struct Ordering: Equatable, Hashable, CustomDebugStringConvertible {
        
        public enum Field: Equatable, Hashable {
            case volume
            case price
            case change
            case score
        }
        
        public let field: Field
        public let direction: OrderingDirection
        
        public var debugDescription: String {
            var description = switch field {
            case .volume:
                "Volume"
            case .price:
                "Price"
            case .change:
                "24H%"
            case .score:
                "Score"
            }
            switch direction {
            case .ascending:
                description += " ↑"
            case .descending:
                description += " ↓"
            }
            return description
        }
        
        public init(field: Field, direction: OrderingDirection) {
            self.field = field
            self.direction = direction
        }
        
        public func directionToggled() -> Ordering {
            Ordering(field: field, direction: direction.toggled())
        }
        
    }
    
}
