import Foundation
import GRDB

public final class PerpsOrderDAO: PerpsDAO {
    
    public static let shared = PerpsOrderDAO()
    
    public static let perpsOrdersDidSaveNotification = Notification.Name(rawValue: "one.mixin.services.PerpsOrderDAO.Save")
    
    private static let itemSQL = """
    SELECT po.*,
        m.token_symbol AS \(PerpetualOrderItem.JoinedQueryCodingKeys.tokenSymbol.rawValue),
        m.display_symbol AS \(PerpetualOrderItem.JoinedQueryCodingKeys.displaySymbol.rawValue),
        m.icon_url AS \(PerpetualOrderItem.JoinedQueryCodingKeys.iconURL.rawValue),
        m.price_scale AS \(PerpetualPositionItem.JoinedQueryCodingKeys.priceScale.rawValue)
    FROM perps_orders po
        LEFT JOIN markets m ON po.market_id = m.market_id
    WHERE po.status != '\(PerpetualOrder.Status.processing.rawValue)'
    
    """
    
    public func orderItems(marketID: String, limit: Int) -> [PerpetualOrderItem] {
        db.select(
            with: Self.itemSQL + "AND po.market_id = ? ORDER BY po.created_at DESC LIMIT ?",
            arguments: [marketID, limit]
        )
    }
    
    public func orderItems(
        offsetUpdatedAt: String?,
        limit: Int?
    ) -> [PerpetualOrderItem] {
        var query = GRDB.SQL(sql: Self.itemSQL)
        if let offsetUpdatedAt {
            query.append(literal: "AND po.updated_at < \(offsetUpdatedAt)\n")
        }
        query.append(literal: "ORDER BY po.created_at DESC\n")
        if let limit {
            query.append(sql: "LIMIT \(limit)")
        }
        return db.select(with: query)
    }
    
    public func offset() -> String? {
        db.select(with: "SELECT updated_at FROM perps_orders ORDER BY updated_at DESC LIMIT 1")
    }
    
    public func save(orders: [PerpetualOrder]) {
        db.save(orders) { _ in
            NotificationCenter.default.post(
                onMainThread: Self.perpsOrdersDidSaveNotification,
                object: self,
                userInfo: nil
            )
        }
    }
    
    public func deleteAll() {
        db.execute(sql: "DELETE FROM perps_orders")
    }
    
}
