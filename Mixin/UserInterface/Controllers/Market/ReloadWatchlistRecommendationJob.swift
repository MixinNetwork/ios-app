import Foundation
import MixinServices

final class ReloadWatchlistRecommendationJob: AsynchronousJob, @unchecked Sendable {
    
    private static var lastReloadingDate: [WatchlistSubCategory: Date] = [:]
    
    private let category: WatchlistSubCategory
    private let refreshInterval: TimeInterval = .hour
    
    init(category: WatchlistSubCategory) {
        self.category = category
    }
    
    override func getJobId() -> String {
        "ReloadWatchlistRcmd-" + category.rawValue
    }
    
    override func execute() -> Bool {
        reload()
        return true
    }
    
    private func reload() {
        guard LoginManager.shared.isLoggedIn, !isCancelled else {
            finishJob()
            return
        }
        let reloadingDate = Queue.main.autoSync {
            Self.lastReloadingDate[category] ?? .distantPast
        }
        let nextReloadingDate = reloadingDate.addingTimeInterval(refreshInterval)
        guard nextReloadingDate.timeIntervalSinceNow <= 0 else {
            Logger.general.debug(category: "ReloadWatchlistRcmd", message: "Not reloading \(category.rawValue) before \(nextReloadingDate)")
            finishJob()
            return
        }
        Logger.general.debug(category: "ReloadWatchlistRcmd", message: "Reload \(category.rawValue)")
        switch category {
        case .crypto:
            RouteAPI.markets(category: .featured, queue: .global(), limit: nil) { result in
                switch result {
                case let .success(markets):
                    MarketDAO.shared.save(
                        markets: markets,
                        replaceRanks: false,
                        updatingCategory: .featured
                    )
                    DispatchQueue.main.async {
                        Self.lastReloadingDate[.crypto] = Date()
                    }
                    Logger.general.debug(category: "ReloadWatchlistRcmd", message: "Updated for cryptos")
                    self.finishJob()
                case let .failure(error):
                    Logger.general.debug(category: "ReloadWatchlistRcmd", message: "\(error)")
                    DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: self.reload)
                }
            }
        case .perps:
            RouteAPI.perpsMarkets(category: .featured, queue: .global()) { result in
                switch result {
                case let .success(markets):
                    PerpsMarketDAO.shared.save(markets: markets, updatingMetadata: .category(.featured))
                    DispatchQueue.main.async {
                        Self.lastReloadingDate[.perps] = Date()
                    }
                    Logger.general.debug(category: "ReloadWatchlistRcmd", message: "Updated for perps")
                    self.finishJob()
                case let .failure(error):
                    Logger.general.debug(category: "ReloadWatchlistRcmd", message: "\(error)")
                    DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: self.reload)
                }
            }
        }
    }
    
}
