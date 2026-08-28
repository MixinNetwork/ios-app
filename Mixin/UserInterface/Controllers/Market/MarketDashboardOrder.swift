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
                return .crypto(.watchlistDefault)
            case .perps:
                return .perps(.watchlistDefault)
            }
        case .crypto:
            let subCategory = MarketDashboardViewController.CryptoSubCategory.allCases[subCategoryIndex]
            return .crypto(.derived(subCategory: subCategory))
        case .perps:
            let subCategory = MarketDashboardViewController.PerpsSubCategory.allCases[subCategoryIndex]
            return .perps(.derived(subCategory: subCategory))
        case .stock:
            switch StockSubCategory.allCases[subCategoryIndex] {
            case .crypto:
                return .crypto(.stocksDefault)
            case .perps:
                return .perps(.stocksDefault)
            }
        case .indicator: // Placeholder only, never triggers
            return .crypto(Market.Ordering(field: .volume, direction: .descending))
        }
    }
    
}

extension Market.Ordering {
    
    static let watchlistDefault = Market.Ordering(field: .addedAt, direction: .descending)
    static let stocksDefault = Market.Ordering(field: .rowid, direction: .ascending)
    
    static func derived(subCategory: MarketDashboardViewController.CryptoSubCategory) -> Market.Ordering {
        switch subCategory {
        case .watchlist:
            watchlistDefault
        case .trending:
            Market.Ordering(field: .rowid, direction: .ascending)
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

extension PerpetualMarket.Ordering {
    
    static let watchlistDefault = PerpetualMarket.Ordering(field: .addedAt, direction: .descending)
    static let stocksDefault = PerpetualMarket.Ordering(field: .score, direction: .descending)
    
    static func derived(subCategory: MarketDashboardViewController.PerpsSubCategory) -> PerpetualMarket.Ordering {
        switch subCategory {
        case .watchlist:
            watchlistDefault
        case .memes, .indices, .commodities, .forex, .trending:
            PerpetualMarket.Ordering(field: .score, direction: .descending)
        case .topGainers:
            PerpetualMarket.Ordering(field: .change, direction: .descending)
        case .topLosers:
            PerpetualMarket.Ordering(field: .change, direction: .ascending)
        }
    }
    
}
