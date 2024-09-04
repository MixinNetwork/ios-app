import UIKit
import MixinServices

final class ReloadGlobalMarketJob: AsynchronousJob {
    
    private static var lastReloadingDate: Date = .distantPast
    
    private let refreshInterval: TimeInterval = 5 * .minute
    
    override func getJobId() -> String {
        "ReloadGlobalMarket"
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
            Self.lastReloadingDate.addingTimeInterval(refreshInterval)
        }
        let interval = reloadingDate.timeIntervalSinceNow
        guard interval <= 0 else {
            Logger.general.debug(category: "ReloadGlobalMarketJob", message: "Not reloading before \(reloadingDate)")
            finishJob()
            return
        }
        RouteAPI.globalMarket(queue: .global()) { result in
            switch result {
            case let .success(market):
                PropertiesDAO.shared.set(market, forKey: .globalMarket)
                DispatchQueue.main.async {
                    Self.lastReloadingDate = Date()
                }
                Logger.general.debug(category: "ReloadGlobalMarketJob", message: "Updated")
                self.finishJob()
            case let .failure(error):
                Logger.general.debug(category: "ReloadGlobalMarketJob", message: "\(error)")
                DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: self.reload)
            }
        }
    }
    
}
