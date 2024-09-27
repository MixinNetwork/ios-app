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
                    let allAssetIDs = Array(Set(alerts.map(\.coinID)))
                    let missingAssetIDs = TokenDAO.shared.inexistAssetIDs(in: allAssetIDs)
                    if !missingAssetIDs.isEmpty {
                        switch SafeAPI.assets(ids: missingAssetIDs) {
                        case .success(let tokens):
                            TokenDAO.shared.save(assets: tokens)
                        case .failure(let error):
                            Logger.general.error(category: "ReloadMarketAlerts", message: "\(error)")
                        }
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
