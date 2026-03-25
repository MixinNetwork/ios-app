import Foundation
import MixinServices

final class PerpetualMarketLoader {
    
    private let marketID: String?
    
    private weak var timer: Timer?
    
    init(marketID: String?) {
        self.marketID = marketID
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func start() {
        guard timer == nil else {
            return
        }
        let timer: Timer = if let marketID {
            .scheduledTimer(
                withTimeInterval: 3,
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
        } else {
            .scheduledTimer(
                withTimeInterval: 3,
                repeats: true
            ) { (timer) in
                RouteAPI.perpsMarkets(queue: .global()) { result in
                    switch result {
                    case .success(let markets):
                        PerpsMarketDAO.shared.save(markets: markets)
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
