import Foundation
import GRDB

public final class PerpsPositionHistoryDAO: PerpsDAO {
    
    public static let shared = PerpsPositionHistoryDAO()
    
    public static let perpsPositionHistoryDidSaveNotification = Notification.Name(rawValue: "one.mixin.services.PerpsPositionHistoryDAO.Save")
    
    private static let itemSQL = """
    SELECT h.*,
        m.token_symbol AS \(PerpetualPositionHistoryItem.JoinedQueryCodingKeys.symbol.rawValue),
        m.symbol AS \(PerpetualPositionHistoryItem.JoinedQueryCodingKeys.product.rawValue),
        m.icon_url AS \(PerpetualPositionHistoryItem.JoinedQueryCodingKeys.iconURL.rawValue)
    FROM position_histories h
        LEFT JOIN markets m ON h.product_id = m.market_id
    
    """
    
    public func historyItems(productID: String) -> [PerpetualPositionHistoryItem] {
        db.select(
            with: Self.itemSQL + "WHERE h.product_id = ? ORDER BY closed_at DESC",
            arguments: [productID]
        )
    }
    
    public func historyItems() -> [PerpetualPositionHistoryItem] {
        db.select(with: Self.itemSQL + "ORDER BY closed_at DESC")
    }
    
    public func offset() -> String? {
        db.select(with: "SELECT closed_at FROM position_histories ORDER BY closed_at DESC LIMIT 1")
    }
    
    public func save(positions: [PerpetualPositionHistory]) {
        db.save(positions) { _ in
            NotificationCenter.default.post(
                onMainThread: Self.perpsPositionHistoryDidSaveNotification,
                object: self,
                userInfo: nil
            )
        }
    }
    
}
