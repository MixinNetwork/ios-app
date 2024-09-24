import Foundation
import GRDB

public final class MarketAlertDAO: UserDatabaseDAO {
    
    public static let shared = MarketAlertDAO()
    
    public static let didSaveNotification = Notification.Name("one.mixin.service.MarketAlertDAO.Save")
    
    public func marketAlerts() -> [MarketAlert] {
        db.selectAll()
    }
    
    public func save(alert: MarketAlert) {
        db.save(alert) { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.didSaveNotification, object: self)
            }
        }
    }
    
    public func replace(alerts: [MarketAlert]) {
        db.write { db in
            try db.execute(sql: "DELETE FROM market_alerts")
            try alerts.save(db)
            db.afterNextTransaction { _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Self.didSaveNotification, object: self)
                }
            }
        }
    }
    
}
