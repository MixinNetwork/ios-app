import Foundation

public final class FavorableMarket: Market {
    
    enum JoinedQueryCodingKeys: String, CodingKey {
        case isFavorite = "is_favored"
    }
    
    public var isFavorite: Bool
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JoinedQueryCodingKeys.self)
        self.isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        try super.init(from: decoder)
    }
    
    public init(market: Market, isFavorite: Bool) {
        self.isFavorite = isFavorite
        super.init(
            coinID: market.coinID,
            name: market.name,
            symbol: market.symbol,
            iconURL: market.iconURL,
            currentPrice: market.currentPrice,
            marketCap: market.marketCap,
            marketCapRank: market.marketCapRank,
            totalVolume: market.totalVolume,
            high24H: market.high24H,
            low24H: market.low24H,
            priceChange24H: market.priceChange24H,
            priceChangePercentage1H: market.priceChangePercentage1H,
            priceChangePercentage24H: market.priceChangePercentage24H,
            priceChangePercentage7D: market.priceChangePercentage7D,
            priceChangePercentage30D: market.priceChangePercentage30D,
            marketCapChange24H: market.marketCapChange24H,
            marketCapChangePercentage24H: market.marketCapChangePercentage24H,
            circulatingSupply: market.circulatingSupply,
            totalSupply: market.totalSupply,
            maxSupply: market.maxSupply,
            ath: market.ath,
            athChangePercentage: market.athChangePercentage,
            athDate: market.athDate,
            atl: market.atl,
            atlChangePercentage: market.atlChangePercentage,
            atlDate: market.atlDate,
            assetIDs: market.assetIDs,
            sparklineIn7D: market.sparklineIn7D,
            updatedAt: market.updatedAt
        )
    }
    
}
