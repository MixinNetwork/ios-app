import Foundation
import GRDB

public final class MarketAlertDAO: UserDatabaseDAO {
    
    public static let shared = MarketAlertDAO()
    
    public static let didChangeNotification = Notification.Name("one.mixin.service.MarketAlertDAO.Change")
    
    public func allMarketAlerts() -> [MarketAlert] {
        db.selectAll()
    }
    
    public func marketAlerts(coinIDs: [String]) -> [MarketAlert] {
        db.select(where: coinIDs.contains(Market.column(of: .coinID)))
    }
    
    public func alertExists(coinID: String) -> Bool {
        db.recordExists(in: MarketAlert.self, where: MarketAlert.column(of: .coinID) == coinID)
    }
    
    public func save(alert: MarketAlert) {
        db.save(alert) { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
            }
        }
    }
    
    public func update(alertID: String, status: MarketAlert.Status) {
        db.update(
            MarketAlert.self,
            assignments: [MarketAlert.column(of: .status).set(to: status.rawValue)],
            where: MarketAlert.column(of: .alertID) == alertID
        ) { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
            }
        }
    }
    
    public func replace(alerts: [MarketAlert]) {
        db.write { db in
            try db.execute(sql: "DELETE FROM market_alerts")
            try alerts.save(db)
            db.afterNextTransaction { _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
                }
            }
        }
    }
    
    public func deleteAlert(id: String) {
        db.delete(MarketAlert.self, where: MarketAlert.column(of: .alertID) == id) { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
            }
        }
    }
    
}
