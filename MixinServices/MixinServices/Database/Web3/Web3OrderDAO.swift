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
    
    public func latestNotPendingCreatedAt() -> String? {
        db.select(with: """
        SELECT created_at FROM orders
        WHERE state NOT IN ('created','pending')
        ORDER BY created_at DESC
        """)
    }
    
    public func pendingOrderIDs() -> [String] {
        db.select(with: "SELECT order_id FROM orders WHERE state IN ('created','pending')")
    }
    
    public func pendingOrders(walletID: String?) -> [SwapOrder] {
        if let walletID {
            db.select(with: """
            SELECT * FROM orders
            WHERE wallet_id = ? AND state IN ('created','pending')
            ORDER BY created_at DESC
            """, arguments: [walletID])
        } else {
            db.select(with: """
            SELECT * FROM orders
            WHERE state IN ('created','pending')
            ORDER BY created_at DESC
            """)
        }
    }
    
    public func save(orders: [SwapOrder]) {
        db.save(orders) { _ in
            NotificationCenter.default.post(
                onMainThread: Self.didSaveNotification,
                object: self,
                userInfo: [Self.ordersUserInfoKey: orders]
            )
        }
    }
    
}
