import GRDB

public final class MembershipOrderDAO: UserDatabaseDAO {
    
    public static let shared = MembershipOrderDAO()
    
    public static let didUpdateNotification = Notification.Name("one.mixin.service.MembershipOrderDAO.Update")
    
    public func orders(limit: Int?) -> [MembershipOrder] {
        var sql = """
        SELECT *
        FROM membership_orders
        ORDER BY created_at DESC
        """
        if let limit {
            sql.append("\nLIMIT \(limit)")
        }
        return db.select(with: sql)
    }
    
    public func save(orders: [MembershipOrder]) {
        guard !orders.isEmpty else {
            return
        }
        db.save(orders) { _ in
            NotificationCenter.default.post(
                onMainThread: Self.didUpdateNotification,
                object: self
            )
        }
    }
    
}
