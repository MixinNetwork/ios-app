import Foundation

public final class FavorablePerpetualMarket: PerpetualMarket {
    
    enum JoinedQueryCodingKeys: String, CodingKey {
        case isFavorite = "is_favored"
    }
    
    public var isFavorite: Bool
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JoinedQueryCodingKeys.self)
        self.isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        try super.init(from: decoder)
    }
    
    public init(market m: PerpetualMarket, isFavorite: Bool) {
        self.isFavorite = isFavorite
        super.init(
            marketID: m.marketID,
            displaySymbol: m.displaySymbol,
            tokenSymbol: m.tokenSymbol,
            quoteSymbol: m.quoteSymbol,
            markPrice: m.markPrice,
            leverage: m.leverage,
            iconURL: m.iconURL,
            fundingRate: m.fundingRate,
            minAmount: m.minAmount,
            maxAmount: m.maxAmount,
            last: m.last,
            volume: m.volume,
            high: m.high,
            low: m.low,
            openPrice: m.openPrice,
            change: m.change,
            bidPrice: m.bidPrice,
            askPrice: m.askPrice,
            createdAt: m.createdAt,
            updatedAt: m.updatedAt,
            category: m.category,
            tags: m.tags,
            priceScale: m.priceScale,
            descriptions: m.descriptions,
            fundingIntervalHours: m.fundingIntervalHours,
            nextFundingAt: m.nextFundingAt,
            openInterest: m.openInterest,
        )
    }
    
}
