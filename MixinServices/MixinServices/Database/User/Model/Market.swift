import Foundation
import GRDB

public class Market: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case coinID = "coin_id"
        case name = "name"
        case symbol = "symbol"
        case iconURL = "icon_url"
        case currentPrice = "current_price"
        case marketCap = "market_cap"
        case marketCapRank = "market_cap_rank"
        case totalVolume = "total_volume"
        case high24H = "high_24h"
        case low24H = "low_24h"
        case priceChange24H = "price_change_24h"
        case priceChangePercentage1H = "price_change_percentage_1h"
        case priceChangePercentage24H = "price_change_percentage_24h"
        case priceChangePercentage7D = "price_change_percentage_7d"
        case priceChangePercentage30D = "price_change_percentage_30d"
        case marketCapChange24H = "market_cap_change_24h"
        case marketCapChangePercentage24H = "market_cap_change_percentage_24h"
        case circulatingSupply = "circulating_supply"
        case totalSupply = "total_supply"
        case maxSupply = "max_supply"
        case ath = "ath"
        case athChangePercentage = "ath_change_percentage"
        case athDate = "ath_date"
        case atl = "atl"
        case atlChangePercentage = "atl_change_percentage"
        case atlDate = "atl_date"
        case assetIDs = "asset_ids"
        case sparklineIn7D = "sparkline_in_7d"
        case updatedAt = "updated_at"
    }
    
    public let coinID: String
    public let name: String
    public let symbol: String
    public let iconURL: String
    public let currentPrice: String
    public let marketCap: String
    public let marketCapRank: String
    public let totalVolume: String
    public let high24H: String
    public let low24H: String
    public let priceChange24H: String
    public let priceChangePercentage1H: String
    public let priceChangePercentage24H: String
    public let priceChangePercentage7D: String
    public let priceChangePercentage30D: String
    public let marketCapChange24H: String
    public let marketCapChangePercentage24H: String
    public let circulatingSupply: String
    public let totalSupply: String
    public let maxSupply: String
    public let ath: String
    public let athChangePercentage: String
    public let athDate: String
    public let atl: String
    public let atlChangePercentage: String
    public let atlDate: String
    public let assetIDs: [String]?
    public let sparklineIn7D: String
    public let updatedAt: String
    
    public private(set) lazy var localizedMarketCap = NamedLargeNumberFormatter.string(
        number: (Decimal(string: marketCap, locale: .enUSPOSIX) ?? 0) * Currency.current.decimalRate,
        currencyPrefix: true
    )
    
    public private(set) lazy var localizedPrice = CurrencyFormatter.localizedString(
        from: (Decimal(string: currentPrice, locale: .enUSPOSIX) ?? 0) * Currency.current.decimalRate,
        format: .fiatMoneyPrice,
        sign: .never,
        symbol: .currencySymbol
    )
    
    public private(set) lazy var decimalPriceChangePercentage7D = Decimal(string: priceChangePercentage7D, locale: .enUSPOSIX) ?? 0
    
    public private(set) lazy var localizedPriceChangePercentage7D = NumberFormatter.percentage.string(decimal: decimalPriceChangePercentage7D / 100)
    
    public private(set) lazy var sparklineIn7DURL = URL(string: sparklineIn7D)
    
}

extension Market: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "markets"
    
}

extension Market {
    
    public enum OrderingExpression: Equatable {
        
        case marketCap(Ordering)
        case price(Ordering)
        case change(Ordering)
        
        public var ordering: Ordering {
            switch self {
            case let .marketCap(ordering):
                ordering
            case let .price(ordering):
                ordering
            case let .change(ordering):
                ordering
            }
        }
        
    }
    
    public enum Ordering {
        
        case ascending
        case descending
        
        public func toggled() -> Ordering {
            switch self {
            case .ascending:
                    .descending
            case .descending:
                    .ascending
            }
        }
        
    }
    
    public enum Limit: CaseIterable {
        
        case top100
        case top200
        case top500
        
        public var count: Int {
            switch self {
            case .top100:
                100
            case .top200:
                200
            case .top500:
                500
            }
        }
        
        public var displayTitle: String {
            "Top \(count)"
        }
        
    }
    
    public enum Category: String {
        case all
        case favorite
    }
    
    public enum ChangePeriod: CaseIterable {
        
        case oneHour
        case twentyFourHours
        case sevenDays
        case thirtyDays
        
        public var shortTitle: String {
            switch self {
            case .oneHour:
                "1h %"
            case .twentyFourHours:
                "24h %"
            case .sevenDays:
                "7D %"
            case .thirtyDays:
                "30D %"
            }
        }
        
        public var fullTitle: String {
            switch self {
            case .oneHour:
                "1 Hour"
            case .twentyFourHours:
                "24 Hours"
            case .sevenDays:
                "7 Days"
            case .thirtyDays:
                "30 Days"
            }
        }
        
    }
    
}
