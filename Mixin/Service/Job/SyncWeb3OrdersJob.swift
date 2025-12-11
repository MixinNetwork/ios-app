import Foundation
import MixinServices

final class SyncWeb3OrdersJob: BaseJob {
    
    private let walletID: String
    private let reloadOpeningOrdersOnFinished: Bool
    private let limit = 300
    
    init(walletID: String, reloadOpeningOrdersOnFinished: Bool) {
        self.walletID = walletID
        self.reloadOpeningOrdersOnFinished = reloadOpeningOrdersOnFinished
        super.init()
    }
    
    static func jobID(walletID: String) -> String {
        "sync-web3-orders-\(walletID)"
    }
    
    override func getJobId() -> String {
        Self.jobID(walletID: walletID)
    }
    
    override func run() throws {
        let initialOffset: String? = Web3PropertiesDAO.shared.orderOffset(walletID: walletID)
        Logger.general.debug(category: "SyncWeb3OrdersJob", message: "Sync from initial offset: \(initialOffset ?? "(null)")")
        var result = RouteAPI.tradeOrders(
            limit: limit,
            offset: initialOffset,
            walletID: walletID,
        )
        while true {
            let orders = try result.get()
            let offset = orders.last?.createdAt
            Logger.general.debug(category: "SyncWeb3OrdersJob", message: "Write \(orders.count) orders, new offset: \(offset ?? "(null)")")
            Web3OrderDAO.shared.save(orders: orders) { [walletID] db in
                if let offset {
                    try Web3PropertiesDAO.shared.set(
                        orderOffset: offset,
                        forWalletWithID: walletID,
                        db: db
                    )
                }
            }
            if orders.count < limit {
                Logger.general.debug(category: "SyncWeb3OrdersJob", message: "Sync finished")
                break
            } else {
                Logger.general.debug(category: "SyncWeb3OrdersJob", message: "Sync from initial offset: \(offset ?? "(null)")")
                result = RouteAPI.tradeOrders(
                    limit: limit,
                    offset: offset,
                    walletID: walletID,
                )
            }
        }
        if reloadOpeningOrdersOnFinished {
            let ids = Web3OrderDAO.shared.openOrderIDs(walletID: walletID)
            guard !ids.isEmpty else {
                return
            }
            Task.detached {
                let orders = try await RouteAPI.tradeOrders(ids: ids)
                Web3OrderDAO.shared.save(orders: orders)
            }
        }
    }
    
}
