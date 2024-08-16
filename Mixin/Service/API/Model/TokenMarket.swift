import Foundation
import MixinServices

struct TokenMarket {
    
    let key: String
    let currentPrice: String
    let marketCap: String
    let marketCapRank: String
    let totalVolume: String
    let high24H: String
    let low24H: String
    let priceChange24H: String
    let priceChangePercentage24H: String
    let marketCapChange24H: String
    let marketCapChangePercentage24H: String
    let circulatingSupply: String
    let totalSupply: String
    let maxSupply: String
    let ath: String
    let athChangePercentage: String
    let athDate: String
    let atl: String
    let atlChangePercentage: String
    let atlDate: String
    let updateAt: String
    
    func asMarket() -> Market {
        Market(
            assetID: key,
            currentPrice: currentPrice,
            marketCap: marketCap,
            marketCapRank: marketCapRank,
            totalVolume: totalVolume,
            high24H: high24H, 
            low24H: low24H,
            priceChange24H: priceChange24H,
            priceChangePercentage24H: priceChangePercentage24H,
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
            updateAt: updateAt
        )
    }
    
}

extension TokenMarket: Codable {
    
    enum CodingKeys: String, CodingKey {
        case key = "key"
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
