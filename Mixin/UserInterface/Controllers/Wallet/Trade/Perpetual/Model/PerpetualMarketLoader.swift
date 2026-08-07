import Foundation
import MixinServices

final class PerpetualMarketLoader {
    
    protocol Delegate: AnyObject {
        func perpetualMarketLoader(
            _ loader: PerpetualMarketLoader,
            didLoadMultipleMarketsIn category: PerpetualMarket.RequestCategory,
            markets: [PerpetualMarket]
        )
    }
    
    enum Request {
        case single(marketID: String)
        case multiple(PerpetualMarket.RequestCategory)
    }
    
    weak var delegate: Delegate?
    
    private let request: Request
    private let timeInterval: TimeInterval
    
    private weak var timer: Timer?
    
    init(request: Request, timeInterval: TimeInterval) {
        self.request = request
        self.timeInterval = timeInterval
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func start() {
        guard timer == nil else {
            return
        }
        let timer: Timer
        switch request {
        case .single(let marketID):
            timer = .scheduledTimer(
                withTimeInterval: timeInterval,
                repeats: true
            ) { (timer) in
                RouteAPI.perpsMarket(marketID: marketID, queue: .global()) { result in
                    switch result {
                    case .success(let market):
                        PerpsMarketDAO.shared.save(market: market)
                        let volume = Decimal(string: market.volume, locale: .enUSPOSIX) ?? 0
                        if volume.isZero {
                            timer.invalidate()
                        }
                    case .failure(let error):
                        Logger.general.debug(category: "PerpMarketLoader", message: "\(error)")
                    }
                }
            }
        case .multiple(let category):
            timer = .scheduledTimer(
                withTimeInterval: timeInterval,
                repeats: true
            ) { [weak self] (timer) in
                RouteAPI.perpsMarkets(category: category, queue: .global()) { result in
                    switch result {
                    case .success(let markets):
                        switch category {
                        case .all:
                            PerpsMarketDAO.shared.save(markets: markets, updatingMetadata: nil)
                        case .favorite:
                            PerpsMarketDAO.shared.save(markets: markets, updatingMetadata: .favorite)
                        case .featured:
                            PerpsMarketDAO.shared.save(markets: markets, updatingMetadata: .category(.featured))
                        }
                        if let self {
                            self.delegate?.perpetualMarketLoader(
                                self,
                                didLoadMultipleMarketsIn: category,
                                markets: markets
                            )
                        }
                    case .failure(let error):
                        Logger.general.debug(category: "PerpMarketLoader", message: "\(error)")
                    }
                }
            }
        }
        self.timer = timer
        timer.fire()
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
}
