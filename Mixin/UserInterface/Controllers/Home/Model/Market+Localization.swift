import Foundation
import MixinServices

extension Market.SubCategory {
    
    var subCategoryDisplay: MarketSubCategoryDisplay {
        switch self {
        case .watchlist:
                .favorite
        case .trending:
                .text(R.string.localizable.trending())
        case .topGainer:
                .text(R.string.localizable.top_gainers())
        case .topLoser:
                .text(R.string.localizable.top_losers())
        case .all:
                .text(R.string.localizable.all())
        }
    }
    
}

extension PerpetualMarket.SubCategory {
    
    var subCategoryDisplay: MarketSubCategoryDisplay {
        switch self {
        case .watchlist:
                .favorite
        case .trending:
                .text(R.string.localizable.trending())
        case .topGainers:
                .text(R.string.localizable.top_gainers())
        case .topLosers:
                .text(R.string.localizable.top_losers())
        case .memes:
                .text(R.string.localizable.perps_category_meme())
        case .indices:
                .text(R.string.localizable.perps_category_indices())
        case .commodities:
                .text(R.string.localizable.perps_category_commodities())
        case .forex:
                .text(R.string.localizable.perps_category_forex())
        }
    }
    
}

extension MarketChangePeriod {
    
    public var displayTitle: String {
        switch self {
        case .twentyFourHours:
            R.string.localizable.hours_count_short(24)
        case .sevenDays:
            R.string.localizable.days_count_short(7)
        }
    }
    
}
