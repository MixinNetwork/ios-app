import Foundation
import GRDB

public final class PerpsPositionDAO: PerpsDAO {
    
    public static let shared = PerpsPositionDAO()
    
    public static let perpsPositionDidChangeNotification = Notification.Name(rawValue: "one.mixin.services.PerpsPositionDAO.Change")
    public static let newPositionItemsUserInfoKey = "np"
    
    private static let itemSQL = """
    SELECT p.*,
        m.token_symbol AS \(PerpetualPositionItem.JoinedQueryCodingKeys.tokenSymbol.rawValue),
        m.display_symbol AS \(PerpetualPositionItem.JoinedQueryCodingKeys.displaySymbol.rawValue),
        m.icon_url AS \(PerpetualPositionItem.JoinedQueryCodingKeys.iconURL.rawValue)
    FROM positions p
        LEFT JOIN markets m ON p.market_id = m.market_id
    
    """
    
    public func count() -> Int {
        db.select(with: "SELECT COUNT(*) FROM positions") ?? 0
    }
    
    public func positionValue() -> PerpetualPositionValue {
        let sql = """
            SELECT
            SUM(ABS(quantity * entry_price)),
            SUM(unrealized_pnl)
            FROM positions
        """
        let (entryValue, pnl) = try! db.read { (db) -> (String, String) in
            let rows = try Row.fetchCursor(db, sql: sql)
            let row = try rows.next()
            return (row?[0] ?? "0", row?[1] ?? "0")
        }
        return .open(entryValue: entryValue, pnl: pnl)
    }
    
    public func position(marketID: String) -> PerpetualPositionItem? {
        db.select(with: Self.itemSQL + "WHERE p.market_id = ?", arguments: [marketID])
    }
    
    public func positionItems() -> [PerpetualPositionItem] {
        db.select(with: Self.itemSQL)
    }
    
    public func replace(positions: [PerpetualPosition]) {
        db.write { db in
            try PerpetualPosition.deleteAll(db)
            try positions.save(db)
            db.afterNextTransaction { _ in
                NotificationCenter.default.post(
                    onMainThread: Self.perpsPositionDidChangeNotification,
                    object: self,
                    userInfo: [Self.newPositionItemsUserInfoKey: []]
                )
            }
        }
    }
    
}
