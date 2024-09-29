import UIKit
import MixinServices

final class ReloadMarketAlertsJob: AsynchronousJob {
    
    override func getJobId() -> String {
        "ReloadMarketAlerts"
    }
    
    override func execute() -> Bool {
        reloadAlerts()
        return true
    }
    
    private func reloadAlerts() {
        guard LoginManager.shared.isLoggedIn, !isCancelled else {
            finishJob()
            return
        }
        RouteAPI.marketAlerts(queue: .global()) { result in
            switch result {
            case let .success(alerts):
                if alerts.isEmpty {
                    self.finishJob()
                } else {
                    self.reloadInexistCoinsIfNeeded(alerts: alerts)
                }
            case let .failure(error):
                Logger.general.debug(category: "ReloadMarketAlerts", message: "\(error)")
                DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: self.reloadAlerts)
            }
        }
    }
    
    private func reloadInexistCoinsIfNeeded(alerts: [MarketAlert]) {
        guard LoginManager.shared.isLoggedIn, !isCancelled else {
            finishJob()
            return
        }
        let allCoinIDs = Set(alerts.map(\.coinID))
        let inexistCoinIDs = MarketDAO.shared.inexistCoinIDs(in: allCoinIDs)
        if inexistCoinIDs.isEmpty {
            MarketAlertDAO.shared.replace(alerts: alerts)
            self.finishJob()
        } else {
            RouteAPI.markets(ids: inexistCoinIDs, queue: .global()) { result in
                switch result {
                case let .success(markets):
                    MarketDAO.shared.save(markets: markets)
                    MarketAlertDAO.shared.replace(alerts: alerts)
                    self.finishJob()
                case let .failure(error):
                    Logger.general.debug(category: "ReloadMarketAlerts", message: "\(error)")
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                        self.reloadInexistCoinsIfNeeded(alerts: alerts)
                    }
                }
            }
        }
    }
    
}
