import Foundation
import GRDB

public struct Market {
    
    public let assetID: String
    public let currentPrice: String
    public let marketCap: String
    public let marketCapRank: String
    public let totalVolume: String
    public let high24H: String
    public let low24H: String
    public let priceChange24H: String
    public let priceChangePercentage24H: String
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
    public let updateAt: String
    
    public init(
        assetID: String, currentPrice: String, marketCap: String,
        marketCapRank: String, totalVolume: String, high24H: String,
        low24H: String, priceChange24H: String,
        priceChangePercentage24H: String, marketCapChange24H: String,
        marketCapChangePercentage24H: String,
        circulatingSupply: String, totalSupply: String,
        maxSupply: String, ath: String, athChangePercentage: String,
        athDate: String, atl: String, atlChangePercentage: String,
        atlDate: String, updateAt: String
    ) {
        self.assetID = assetID
        self.currentPrice = currentPrice
        self.marketCap = marketCap
        self.marketCapRank = marketCapRank
        self.totalVolume = totalVolume
        self.high24H = high24H
        self.low24H = low24H
        self.priceChange24H = priceChange24H
        self.priceChangePercentage24H = priceChangePercentage24H
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
        self.updateAt = updateAt
    }
    
}

extension Market: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case assetID = "asset_id"
        case currentPrice = "current_price"
        case marketCap = "market_cap"
        case marketCapRank = "market_cap_rank"
        case totalVolume = "total_volume"
        case high24H = "high_24h"
        case low24H = "low_24h"
        case priceChange24H = "price_change_24h"
        case priceChangePercentage24H = "price_change_percentage_24h"
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
        case updateAt = "updated_at"
    }
    
}

extension Market: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "markets"
    
}
