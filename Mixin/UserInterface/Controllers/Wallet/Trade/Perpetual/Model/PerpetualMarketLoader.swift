import Foundation
import MixinServices

final class PerpetualMarketLoader {
    
    private weak var timer: Timer?
    
    deinit {
        timer?.invalidate()
    }
    
    func start() {
        guard timer == nil else {
            return
        }
        let timer: Timer = .scheduledTimer(
            withTimeInterval: 3,
            repeats: true
        ) { (timer) in
            RouteAPI.perpsMarkets(queue: .global()) { result in
                switch result {
                case .success(let markets):
                    PerpsMarketDAO.shared.replace(markets: markets)
                case .failure(let error):
                    Logger.general.debug(category: "PerpMarketLoader", message: "\(error)")
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
