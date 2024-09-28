import UIKit
import MixinServices

final class ReloadMarketAlertsJob: AsynchronousJob {
    
    override func getJobId() -> String {
        "ReloadMarketAlerts"
    }
    
    override func execute() -> Bool {
        RouteAPI.marketAlerts(queue: .global()) { result in
            switch result {
            case let .success(alerts):
                if !alerts.isEmpty {
                    let allCoinIDs = Array(Set(alerts.map(\.coinID)))
                    let inexistCoinIDs = MarketDAO.shared.inexistCoinIDs(in: allCoinIDs)
                    if !inexistCoinIDs.isEmpty {
                        // FIXME: Load missing markets
                    }
                }
                MarketAlertDAO.shared.replace(alerts: alerts)
            case let .failure(error):
                Logger.general.error(category: "ReloadMarketAlerts", message: "\(error)")
            }
            self.finishJob()
        }
        return true
    }
    
}
