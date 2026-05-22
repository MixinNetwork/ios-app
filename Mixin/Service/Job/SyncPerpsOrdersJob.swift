import Foundation
import MixinServices

final class SyncPerpsOrdersJob: AsynchronousJob {

    private let walletID: String
    private let limit = 100
    
    init(walletID: String) {
        self.walletID = walletID
        super.init()
    }
    
    public override func getJobId() -> String {
        "sync-perps-orders-\(walletID)"
    }
    
    public override func execute() -> Bool {
        let initialOffset = PerpsOrderDAO.shared.offset()
        Logger.general.debug(category: "SyncPerpsOrders", message: "wid: \(walletID), offset: \(initialOffset ?? "(null)")")
        Task {
            do {
                var orders = try await RouteAPI.perpsOrders(
                    walletID: walletID,
                    offset: initialOffset,
                    limit: limit
                )
                while true {
                    Logger.general.debug(category: "SyncPerpsOrders", message: "Write \(orders.count) orders")
                    PerpsOrderDAO.shared.save(orders: orders)
                    if let offset = orders.last, orders.count >= limit {
                        orders = try await RouteAPI.perpsOrders(
                            walletID: walletID,
                            offset: offset.updatedAt,
                            limit: limit
                        )
                    } else {
                        Logger.general.debug(category: "SyncPerpsOrders", message: "Sync finished")
                        break
                    }
                }
            } catch {
                Logger.general.debug(category: "SyncPerpsOrders", message: "\(error)")
            }
            finishJob()
        }
        return true
    }
    
}
