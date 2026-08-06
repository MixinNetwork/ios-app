import Foundation
import MixinServices

final class MarketPeriodicRequester {
    
    protocol Delegate: AnyObject {
        func marketPeriodicRequester(
            _ requester: MarketPeriodicRequester,
            didLoadMarketsIn category: Market.RequestCategory,
            markets: [Market]
        )
    }
    
    weak var delegate: Delegate?
    
    private let category: Market.RequestCategory
    private let limit: Int
    private let modelName: String
    private let refreshInterval: TimeInterval = 30
    
    private var isRunning = false
    private var lastReloadingDate: Date = .distantPast
    
    private weak var timer: Timer?
    
    init(category: Market.RequestCategory, limit: Int) {
        self.category = category
        self.limit = limit
        self.modelName = switch category {
        case .all:
            "markets"
        default:
            category.rawValue
        }
    }
    
    func start() {
        assert(Thread.isMainThread)
        guard !isRunning else {
            return
        }
        isRunning = true
        let delay = lastReloadingDate.addingTimeInterval(refreshInterval).timeIntervalSinceNow
        if delay <= 0 {
            Logger.general.debug(category: "MarketPeriodicRequester", message: "Load \(modelName) now")
            requestData()
        } else {
            Logger.general.debug(category: "MarketPeriodicRequester", message: "Load \(modelName) after \(delay)s")
            scheduleNextRequestIfRunning(timeInterval: delay)
        }
    }
    
    func pause() {
        assert(Thread.isMainThread)
        Logger.general.debug(category: "MarketPeriodicRequester", message: "Pause loading \(modelName)")
        isRunning = false
        timer?.invalidate()
    }
    
    private func requestData() {
        assert(Thread.isMainThread)
        timer?.invalidate()
        Logger.general.debug(category: "MarketPeriodicRequester", message: "Request \(modelName)")
        guard LoginManager.shared.isLoggedIn else {
            return
        }
        RouteAPI.markets(
            category: category,
            queue: .global(),
            limit: limit,
        ) { [weak self, refreshInterval, category, modelName] result in
            switch result {
            case let .success(markets):
                Logger.general.debug(category: "MarketPeriodicRequester", message: "Loaded \(markets.count) \(modelName)")
                switch category {
                case .all:
                    MarketDAO.shared.save(markets: markets, replaceRanks: true, updatingCategory: nil)
                case .favorite:
                    MarketDAO.shared.replace(favoriteMarkets: markets)
                case .trending:
                    MarketDAO.shared.save(markets: markets, replaceRanks: false, updatingCategory: .trending)
                case .stocks:
                    MarketDAO.shared.save(markets: markets, replaceRanks: false, updatingCategory: .stock)
                case .topGainers:
                    MarketDAO.shared.save(markets: markets, replaceRanks: false, updatingCategory: .topGainer)
                case .topLosers:
                    MarketDAO.shared.save(markets: markets, replaceRanks: false, updatingCategory: .topLoser)
                case .featured:
                    MarketDAO.shared.save(markets: markets, replaceRanks: false, updatingCategory: .featured)
                }
                if let self {
                    self.delegate?.marketPeriodicRequester(self, didLoadMarketsIn: category, markets: markets)
                }
                DispatchQueue.main.async {
                    Logger.general.debug(category: "MarketPeriodicRequester", message: "Reload \(modelName) after \(refreshInterval)s")
                    if let self {
                        self.lastReloadingDate = Date()
                        self.scheduleNextRequestIfRunning(timeInterval: refreshInterval)
                    }
                }
            case let .failure(error):
                Logger.general.debug(category: "MarketPeriodicRequester", message: "Load \(modelName): \(error)")
                DispatchQueue.main.async {
                    self?.scheduleNextRequestIfRunning(timeInterval: 3)
                }
            }
        }
    }
    
    private func scheduleNextRequestIfRunning(timeInterval: TimeInterval) {
        guard isRunning else {
            return
        }
        timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            self?.requestData()
        }
    }
    
}
