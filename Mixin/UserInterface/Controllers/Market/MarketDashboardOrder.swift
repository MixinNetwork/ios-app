import Foundation
import MixinServices

enum MarketDashboardOrder: Equatable, CustomDebugStringConvertible {
    
    case crypto(Market.Ordering)
    case perps(PerpetualMarket.Ordering)
    
    var debugDescription: String {
        switch self {
        case .crypto(let order):
            order.debugDescription
        case .perps(let order):
            order.debugDescription
        }
    }
    
    var direction: OrderingDirection {
        switch self {
        case .crypto(let ordering):
            ordering.direction
        case .perps(let ordering):
            ordering.direction
        }
    }
    
    var cryptoOrdering: Market.Ordering? {
        switch self {
        case .crypto(let ordering):
            ordering
        case .perps:
            nil
        }
    }
    
    var perpsOrdering: PerpetualMarket.Ordering? {
        switch self {
        case .crypto:
            nil
        case .perps(let ordering):
            ordering
        }
    }
    
    static func derived(
        category: MarketDashboardViewController.Category,
        subCategoryIndex: Int
    ) -> MarketDashboardOrder {
        switch category {
        case .watchlist:
            switch WatchlistSubCategory.allCases[subCategoryIndex] {
            case .crypto:
                .crypto(.derived(category: category, subCategoryIndex: subCategoryIndex))
            case .perps:
                .perps(.derived(category: category, subCategoryIndex: subCategoryIndex))
            }
        case .crypto, .indicator:
            .crypto(.derived(category: category, subCategoryIndex: subCategoryIndex))
        case .perps:
            .perps(.derived(category: category, subCategoryIndex: subCategoryIndex))
        }
    }
    
}

extension Market.Ordering {
    
    static func derived(
        category: MarketDashboardViewController.Category,
        subCategoryIndex: Int
    ) -> Market.Ordering {
        switch category {
        case .watchlist, .perps, .indicator:
            Market.Ordering(field: .volume, direction: .descending)
        case .crypto:
            switch Market.SubCategory.allCases[subCategoryIndex] {
            case .watchlist, .trending:
                Market.Ordering(field: .volume, direction: .descending)
            case .topGainer:
                Market.Ordering(
                    field: .change(AppGroupUserDefaults.User.cryptoMarketChangePeriod),
                    direction: .descending
                )
            case .topLoser:
                Market.Ordering(
                    field: .change(AppGroupUserDefaults.User.cryptoMarketChangePeriod),
                    direction: .ascending
                )
            case .all:
                Market.Ordering(field: .marketCap, direction: .descending)
            }
        }
    }
    
}

extension PerpetualMarket.Ordering {
    
    static func derived(
        category: MarketDashboardViewController.Category,
        subCategoryIndex: Int
    ) -> PerpetualMarket.Ordering {
        switch category {
        case .watchlist, .crypto, .indicator:
            PerpetualMarket.Ordering(field: .volume, direction: .descending)
        case .perps:
            switch MarketDashboardViewController.PerpsSubCategory.allCases[subCategoryIndex] {
            case .watchlist, .memes, .indices, .commodities, .forex:
                PerpetualMarket.Ordering(field: .volume, direction: .descending)
            case .trending:
                PerpetualMarket.Ordering(field: .score, direction: .descending)
            case .topGainers:
                PerpetualMarket.Ordering(
                    field: .change,
                    direction: .descending
                )
            case .topLosers:
                PerpetualMarket.Ordering(
                    field: .change,
                    direction: .ascending
                )
            }
        }
    }
    
}
