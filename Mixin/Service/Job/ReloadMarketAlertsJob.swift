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
                    Logger.general.debug(category: "ReloadMarketAlerts", message: "Loaded 0 alerts")
                    self.finishJob()
                } else {
                    self.reloadInexistCoinsIfNeeded(alerts: alerts)
                }
            case .failure:
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
            Logger.general.debug(category: "ReloadMarketAlerts", message: "Loaded \(alerts.count) alerts")
            MarketAlertDAO.shared.replace(alerts: alerts)
            self.finishJob()
        } else {
            RouteAPI.markets(ids: inexistCoinIDs, queue: .global()) { result in
                switch result {
                case let .success(markets):
                    Logger.general.debug(category: "ReloadMarketAlerts", message: "Loaded \(alerts.count) alerts")
                    MarketDAO.shared.save(markets: markets, dataSource: .other)
                    MarketAlertDAO.shared.replace(alerts: alerts)
                    self.finishJob()
                case .failure:
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                        self.reloadInexistCoinsIfNeeded(alerts: alerts)
                    }
                }
            }
        }
    }
    
}
