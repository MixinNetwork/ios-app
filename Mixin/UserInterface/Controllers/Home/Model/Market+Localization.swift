import Foundation
import MixinServices

extension Market.SubCategory {
    
    var displayTitle: String {
        switch self {
        case .watchlist:
            "☆"
        case .trending:
            R.string.localizable.trending()
        case .topGainer:
            R.string.localizable.top_gainers()
        case .topLoser:
            R.string.localizable.top_losers()
        case .all:
            R.string.localizable.all()
        }
    }
    
}

extension PerpetualMarket.SubCategory {
    
    var displayTitle: String {
        switch self {
        case .watchlist:
            "☆"
        case .trending:
            R.string.localizable.trending()
        case .topGainers:
            R.string.localizable.top_gainers()
        case .topLosers:
            R.string.localizable.top_losers()
        case .memes:
            R.string.localizable.perps_category_meme()
        case .indices:
            R.string.localizable.perps_category_indices()
        case .commodities:
            R.string.localizable.perps_category_commodities()
        case .forex:
            R.string.localizable.perps_category_forex()
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
