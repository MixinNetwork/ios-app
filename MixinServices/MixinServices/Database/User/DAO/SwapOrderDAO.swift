import Foundation
import GRDB

public final class SwapOrderDAO: UserDatabaseDAO {
    
    public static let shared = SwapOrderDAO()
    
    public static let didChangeNotification = Notification.Name("one.mixin.service.MarketAlertDAO.Change")
    
    private let selector = """
    SELECT o.order_id, o.pay_asset_id, o.receive_asset_id,
        pt.symbol AS pay_symbol, rt.symbol AS receive_symbol,
        pt.icon_url AS pay_icon, rt.icon_url AS receive_icon,
        pc.name AS pay_chain_name, rc.name AS receive_chain_name,
        o.pay_amount, o.receive_amount,
        o.created_at, o.state, o.order_type
    FROM swap_orders o
        LEFT JOIN tokens pt ON o.pay_asset_id = pt.asset_id
        LEFT JOIN tokens rt ON o.receive_asset_id = rt.asset_id
        LEFT JOIN chains pc ON pt.chain_id = pc.chain_id
        LEFT JOIN chains rc ON rt.chain_id = rc.chain_id
    """
    
    public func orders(before offset: String? = nil, limit: Int) -> [SwapOrderItem] {
        var sql = self.selector
        var arguments: [any DatabaseValueConvertible] = []
        if let offset {
            sql += "\nWHERE o.created_at < ?"
            arguments.append(offset)
        }
        sql += "\nORDER BY o.created_at DESC\nLIMIT ?"
        arguments.append(limit)
        return db.select(with: sql, arguments: StatementArguments(arguments))
    }
    
    public func orderExists(orderID: String) -> Bool {
        db.recordExists(in: SwapOrder.self, where: SwapOrder.column(of: .orderID) == orderID)
    }
    
    public func saveAndFetch(orders: [SwapOrder]) -> [SwapOrderItem] {
        guard let oldestOrder = orders.first, let newestOrder = orders.last else {
            return []
        }
        assert(oldestOrder.createdAt < newestOrder.createdAt)
        let sql = selector + """
        
        WHERE o.created_at <= ? AND o.created_at >= ?
        ORDER BY o.created_at DESC
        """
        return try! db.writeAndReturnError { db in
            try orders.save(db)
            return try SwapOrderItem.fetchAll(
                db,
                sql: sql,
                arguments: [newestOrder.createdAt, oldestOrder.createdAt]
            )
        }
    }
    
}
