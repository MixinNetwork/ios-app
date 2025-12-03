import Foundation
import GRDB

public final class Web3OrderDAO: Web3DAO {
    
    public static let shared = Web3OrderDAO()
    
    public static let didSaveNotification = Notification.Name("one.mixin.service.Web3OrderDAO.Save")
    public static let ordersUserInfoKey = "o"
    
    public func order(id: String) -> TradeOrder? {
        db.select(with: "SELECT * FROM orders WHERE order_id = ?", arguments: [id])
    }
    
    public func orders(ids: [String]) -> [TradeOrder] {
        let query: GRDB.SQL = "SELECT * FROM orders WHERE order_id IN \(ids)"
        return db.select(with: query)
    }
    
    public func assetIDs(walletIDs: [String]) -> [String] {
        let query: GRDB.SQL = """
        SELECT asset_id
        FROM (
            SELECT asset_id, MAX(created_at) AS created_at
            FROM (
                SELECT pay_asset_id AS asset_id, created_at FROM orders WHERE wallet_id IN \(walletIDs)
                UNION ALL
                SELECT receive_asset_id AS asset_id, created_at FROM orders WHERE wallet_id IN \(walletIDs)
            )
            GROUP BY asset_id
        )
        ORDER BY created_at DESC
        """
        return db.select(with: query)
    }
    
    public func openOrders(walletID: String, type: TradeOrder.OrderType) -> [TradeOrder] {
        db.select(
            with: """
            SELECT *
            FROM orders
            WHERE wallet_id = ?
                AND order_type = ?
                AND state IN ('created','pending','cancelling')
            ORDER BY created_at DESC
            """,
            arguments: [walletID, type.rawValue]
        )
    }
    
    public func openOrdersCount(walletID: String) -> Int {
        let count: Int? = db.select(
            with: """
            SELECT COUNT(*)
            FROM orders
            WHERE wallet_id = ?
                AND state IN ('created','pending','cancelling')
            """,
            arguments: [walletID]
        )
        return count ?? 0
    }
    
    public func openOrderIDs(walletID: String) -> [String] {
        db.select(
            with: """
               SELECT order_id
               FROM orders
               WHERE wallet_id = ?
                   AND state IN ('created','pending','cancelling')
               """,
            arguments: [walletID]
        )
    }
    
    public func save(
        orders: [TradeOrder],
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
