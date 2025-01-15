import Foundation
import GRDB

public class Market: Codable, DatabaseColumnConvertible, MixinFetchableRecord {
    
    public enum CodingKeys: String, CodingKey, CaseIterable {
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
        case sparklineIn24H = "sparkline_in_24h"
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
    public let sparklineIn24H: String
    public let updatedAt: String
    
    public private(set) lazy var localizedMarketCap = NamedLargeNumberFormatter.string(
        number: (Decimal(string: marketCap, locale: .enUSPOSIX) ?? 0) * Currency.current.decimalRate,
        currencyPrefix: true
    )
    
    public private(set) lazy var numberedRank: String? = {
        if marketCapRank.isEmpty  {
            nil
        } else {
            "#" + marketCapRank
        }
    }()
    
    public private(set) lazy var localizedUSDPrice = CurrencyFormatter.localizedString(
        from: decimalPrice,
        format: .fiatMoneyPrice,
        sign: .never,
        symbol: .custom("USD")
    )
    
    public private(set) lazy var localizedPrice = CurrencyFormatter.localizedString(
        from: decimalPrice * Currency.current.decimalRate,
        format: .fiatMoneyPrice,
        sign: .never,
        symbol: .currencySymbol
    )
    
    public private(set) lazy var decimalPrice = Decimal(string: currentPrice, locale: .enUSPOSIX) ?? 0
    
    public private(set) lazy var decimalPriceChangePercentage7D = Decimal(string: priceChangePercentage7D, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var localizedPriceChangePercentage7D = NumberFormatter.percentage.string(decimal: decimalPriceChangePercentage7D / 100)
    public private(set) lazy var sparklineIn7DURL = URL(string: sparklineIn7D)
    
    public private(set) lazy var decimalPriceChangePercentage24H = Decimal(string: priceChangePercentage24H, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var localizedPriceChangePercentage24H = NumberFormatter.percentage.string(decimal: decimalPriceChangePercentage24H / 100)
    public private(set) lazy var sparklineIn24HURL = URL(string: sparklineIn24H)
    
    init(
        coinID: String, name: String, symbol: String, iconURL: String, currentPrice: String,
        marketCap: String, marketCapRank: String, totalVolume: String, high24H: String,
        low24H: String, priceChange24H: String, priceChangePercentage1H: String,
        priceChangePercentage24H: String, priceChangePercentage7D: String,
        priceChangePercentage30D: String, marketCapChange24H: String,
        marketCapChangePercentage24H: String, circulatingSupply: String, 
        totalSupply: String, maxSupply: String, ath: String, athChangePercentage: String,
        athDate: String, atl: String, atlChangePercentage: String, atlDate: String,
        assetIDs: [String]?, sparklineIn7D: String, sparklineIn24H: String, updatedAt: String
    ) {
        self.coinID = coinID
        self.name = name
        self.symbol = symbol
        self.iconURL = iconURL
        self.currentPrice = currentPrice
        self.marketCap = marketCap
        self.marketCapRank = marketCapRank
        self.totalVolume = totalVolume
        self.high24H = high24H
        self.low24H = low24H
        self.priceChange24H = priceChange24H
        self.priceChangePercentage1H = priceChangePercentage1H
        self.priceChangePercentage24H = priceChangePercentage24H
        self.priceChangePercentage7D = priceChangePercentage7D
        self.priceChangePercentage30D = priceChangePercentage30D
        self.marketCapChange24H = marketCapChange24H
        self.marketCapChangePercentage24H = marketCapChangePercentage24H
        self.circulatingSupply = circulatingSupply
        self.totalSupply = totalSupply
        self.maxSupply = maxSupply
        self.ath = ath
        self.athChangePercentage = athChangePercentage
        self.athDate = athDate
        self.atl = atl
        self.atlChangePercentage = atlChangePercentage
        self.atlDate = atlDate
        self.assetIDs = assetIDs
        self.sparklineIn7D = sparklineIn7D
        self.sparklineIn24H = sparklineIn24H
        self.updatedAt = updatedAt
    }
    
    public func replacingMarketCapRank(with rank: String) -> Market {
        Market(
            coinID: coinID,
            name: name,
            symbol: symbol,
            iconURL: iconURL,
            currentPrice: currentPrice,
            marketCap: marketCap,
            marketCapRank: rank,
            totalVolume: totalVolume,
            high24H: high24H,
            low24H: low24H,
            priceChange24H: priceChange24H,
            priceChangePercentage1H: priceChangePercentage1H,
            priceChangePercentage24H: priceChangePercentage24H,
            priceChangePercentage7D: priceChangePercentage7D,
            priceChangePercentage30D: priceChangePercentage30D,
            marketCapChange24H: marketCapChange24H,
            marketCapChangePercentage24H: marketCapChangePercentage24H,
            circulatingSupply: circulatingSupply,
            totalSupply: totalSupply,
            maxSupply: maxSupply,
            ath: ath,
            athChangePercentage: athChangePercentage,
            athDate: athDate,
            atl: atl,
            atlChangePercentage: atlChangePercentage,
            atlDate: atlDate,
            assetIDs: assetIDs,
            sparklineIn7D: sparklineIn7D,
            sparklineIn24H: sparklineIn24H,
            updatedAt: updatedAt
        )
    }
    
}

extension Market: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "markets"
    
}

extension Market {
    
    public enum OrderingExpression: Equatable {
        
        case marketCap(Ordering)
        case price(Ordering)
        case change(period: ChangePeriod, ordering: Ordering)
        
        public var ordering: Ordering {
            switch self {
            case let .marketCap(ordering):
                ordering
            case let .price(ordering):
                ordering
            case let .change(_, ordering):
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
        
    }
    
    public enum Category: String {
        case all
        case favorite
    }
    
    public enum ChangePeriod: Int, CaseIterable {
        case twentyFourHours    = 0
        case sevenDays          = 1
    }
    
}

extension Market {
    
    struct MarketCapRankStorage: Codable, MixinEncodableRecord, PersistableRecord {
        
        enum CodingKeys: String, CodingKey {
            case coinID = "coin_id"
            case marketCapRank = "market_cap_rank"
            case updatedAt = "updated_at"
        }
        
        static let databaseTableName = "market_cap_ranks"
        
        let coinID: String
        let marketCapRank: String
        let updatedAt: String
        
    }
    
    var rankStorage: MarketCapRankStorage {
        MarketCapRankStorage(
            coinID: coinID,
            marketCapRank: marketCapRank,
            updatedAt: updatedAt
        )
    }
    
}
