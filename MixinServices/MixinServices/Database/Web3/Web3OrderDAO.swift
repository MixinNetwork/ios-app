import Foundation
import GRDB

public final class Web3OrderDAO: Web3DAO {
    
    public static let shared = Web3OrderDAO()
    
    public static let didSaveNotification = Notification.Name("one.mixin.service.Web3OrderDAO.Save")
    public static let ordersUserInfoKey = "o"
    
    public func order(id: String) -> SwapOrder? {
        db.select(with: "SELECT * FROM orders WHERE order_id = ?", arguments: [id])
    }
    
    public func orders(ids: [String]) -> [SwapOrder] {
        let query: GRDB.SQL = "SELECT * FROM orders WHERE order_id IN \(ids)"
        return db.select(with: query)
    }
    
    public func pendingOrders(walletID: String) -> [SwapOrder] {
        db.select(with: """
        SELECT *
        FROM orders
        WHERE wallet_id = ?
            AND state IN ('created','pending')
        ORDER BY created_at DESC
        """, arguments: [walletID])
    }
    
    public func pendingOrdersCount(walletID: String) -> Int {
        let count: Int? = db.select(
            with: "SELECT COUNT(*) FROM orders WHERE wallet_id = ? AND state IN ('created','pending')",
            arguments: [walletID]
        )
        return count ?? 0
    }
    
    public func save(
        orders: [SwapOrder],
        alongsideTransaction change: ((GRDB.Database) throws -> Void)? = nil
    ) {
        db.write { db in
            try orders.save(db)
            try change?(db)
            db.afterNextTransaction { _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Self.didSaveNotification,
                        object: self,
                        userInfo: [Self.ordersUserInfoKey: orders]
                    )
                }
            }
        }
    }
    
    public func deleteAll() {
        db.execute(sql: "DELETE FROM orders")
    }
    
}
