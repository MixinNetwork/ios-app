import Foundation
import GRDB

public final class PerpsPositionHistoryDAO: PerpsDAO {
    
    public static let shared = PerpsPositionHistoryDAO()
    
    public static let perpsPositionHistoryDidSaveNotification = Notification.Name(rawValue: "one.mixin.services.PerpsPositionHistoryDAO.Save")
    
    private static let itemSQL = """
    SELECT h.*,
        m.token_symbol AS \(PerpetualPositionHistoryItem.JoinedQueryCodingKeys.tokenSymbol.rawValue),
        m.display_symbol AS \(PerpetualPositionHistoryItem.JoinedQueryCodingKeys.displaySymbol.rawValue),
        m.icon_url AS \(PerpetualPositionHistoryItem.JoinedQueryCodingKeys.iconURL.rawValue)
    FROM position_histories h
        LEFT JOIN markets m ON h.market_id = m.market_id
    
    """
    
    public func positionValue() -> PerpetualPositionValue {
        let sql = "SELECT SUM(realized_pnl) FROM position_histories"
        let pnl: String = try! db.read { (db) in
            let rows = try Row.fetchCursor(db, sql: sql)
            let row = try rows.next()
            return row?[0] ?? "0"
        }
        return .closed(pnl: pnl)
    }
    
    public func historyItems(marketID: String) -> [PerpetualPositionHistoryItem] {
        db.select(
            with: Self.itemSQL + "WHERE h.market_id = ? ORDER BY closed_at DESC",
            arguments: [marketID]
        )
    }
    
    public func historyItems(
        offsetClosedAt: String?,
        limit: Int?
    ) -> [PerpetualPositionHistoryItem] {
        var query = GRDB.SQL(sql: Self.itemSQL)
        if let offsetClosedAt {
            query.append(literal: "WHERE closed_at < \(offsetClosedAt)\n")
        }
        query.append(literal: "ORDER BY closed_at DESC\n")
        if let limit {
            query.append(sql: "LIMIT \(limit)")
        }
        return db.select(with: query)
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
