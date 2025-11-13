import Foundation
import MixinServices

final class SyncWeb3OrdersJob: BaseJob {
    
    private let limit = 300
    
    override func getJobId() -> String {
        "sync-web3-orders"
    }
    
    override func run() throws {
        let initialOffset = Web3OrderDAO.shared.latestNotPendingCreatedAt()
        Logger.general.debug(category: "SyncWeb3OrdersJob", message: "Sync from initial offset: \(initialOffset ?? "(null)")")
        var result = RouteAPI.swapOrders(
            category: .all,
            state: nil,
            limit: limit,
            offset: initialOffset
        )
        while true {
            let orders = try result.get()
            let offset = orders.last?.createdAt
            Logger.general.debug(category: "SyncWeb3OrdersJob", message: "Write \(orders.count) orders, new offset: \(offset ?? "(null)")")
            Web3OrderDAO.shared.save(orders: orders)
            if orders.count < limit {
                Logger.general.debug(category: "SyncWeb3OrdersJob", message: "Sync finished")
                break
            } else {
                Logger.general.debug(category: "SyncWeb3OrdersJob", message: "Sync from initial offset: \(offset ?? "(null)")")
                result = RouteAPI.swapOrders(
                    category: .all,
                    state: nil,
                    limit: limit,
                    offset: offset
                )
            }
        }
    }
    
}
