import Foundation
import MixinServices

extension MarketOrdering {
    
    static func derived(
        category: MarketDashboardViewController.Category,
        subCategoryIndex: Int
    ) -> MarketOrdering? {
        switch category {
        case .watchlist:
            nil
        case .crypto:
            switch Market.SubCategory.allCases[subCategoryIndex] {
            case .watchlist:
                nil
            case .trending:
                MarketOrdering(field: .volume, direction: .descending)
            case .topGainer:
                MarketOrdering(
                    field: .change(period: AppGroupUserDefaults.User.cryptoMarketChangePeriod),
                    direction: .descending
                )
            case .topLoser:
                MarketOrdering(
                    field: .change(period: AppGroupUserDefaults.User.cryptoMarketChangePeriod),
                    direction: .ascending
                )
            case .all:
                MarketOrdering(field: .marketCap, direction: .descending)
            }
        case .perps:
            switch PerpetualMarket.SubCategory.allCases[subCategoryIndex] {
            case .watchlist:
                nil
            case .trending, .memes, .indices, .commodities, .forex:
                MarketOrdering(field: .volume, direction: .descending)
            case .topGainers:
                MarketOrdering(
                    field: .change(period: .twentyFourHours),
                    direction: .descending
                )
            case .topLosers:
                MarketOrdering(
                    field: .change(period: .twentyFourHours),
                    direction: .ascending
                )
            }
        case .indicator:
            nil
        }
    }
    
}
