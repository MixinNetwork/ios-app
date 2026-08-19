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
