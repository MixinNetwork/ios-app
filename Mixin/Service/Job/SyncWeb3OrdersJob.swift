import Foundation
import MixinServices

final class SyncWeb3OrdersJob: BaseJob {
    
    private let walletID: String
    private let limit = 300
    
    init(walletID: String) {
        self.walletID = walletID
        super.init()
    }
    
    static func jobID(walletID: String) -> String {
        "sync-web3-orders-\(walletID)"
    }
    
    override func getJobId() -> String {
        Self.jobID(walletID: walletID)
    }
    
    override func run() throws {
        let offsetKey: PropertiesDAO.Key = .orderOffset(walletID: walletID)
        let initialOffset: String? = PropertiesDAO.shared.value(forKey: offsetKey)
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
            Web3OrderDAO.shared.save(orders: orders) { db in
                if let offset {
                    try PropertiesDAO.shared.set(offset, forKey: offsetKey, db: db)
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
    }
    
}
