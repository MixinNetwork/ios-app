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
        m.icon_url AS \(PerpetualPositionItem.JoinedQueryCodingKeys.iconURL.rawValue),
        m.price_scale AS \(PerpetualPositionItem.JoinedQueryCodingKeys.priceScale.rawValue)
    FROM positions p
        LEFT JOIN markets m ON p.market_id = m.market_id
    
    """
    
    public func count() -> Int {
        db.select(with: "SELECT COUNT(*) FROM positions") ?? 0
    }
    
    public func positionValue() -> PerpetualPositionValue {
        let sql = "SELECT SUM(margin), SUM(unrealized_pnl) FROM positions"
        let (margin, pnl) = try! db.read { (db) -> (String, String) in
            let rows = try Row.fetchCursor(db, sql: sql)
            let row = try rows.next()
            return (row?[0] ?? "0", row?[1] ?? "0")
        }
        return .open(margin: margin, pnl: pnl)
    }
    
    public func position(marketID: String) -> PerpetualPositionItem? {
        db.select(with: Self.itemSQL + "WHERE p.market_id = ?", arguments: [marketID])
    }
    
    public func save(position: PerpetualPosition) -> PerpetualPositionItem? {
        try? db.writeAndReturnError { db in
            try position.save(db)
            return try PerpetualPositionItem.fetchOne(
                db,
                sql: Self.itemSQL + "WHERE p.position_id = ? LIMIT 1",
                arguments: [position.positionID]
            )
        }
    }
    
    public func positionItems() -> [PerpetualPositionItem] {
        db.select(with: Self.itemSQL + "ORDER BY created_at DESC")
    }
    
    // Returns if there's difference between old and new ones
    public func replace(positions: [PerpetualPosition]) -> Bool {
        try! db.writeAndReturnError { (db) -> Bool in
            let positionsBefore = try PerpetualPositionUniqueIdentifier.fetchSet(
                db,
                sql: "SELECT position_id, open_pay_amount FROM positions"
            )
            let positionsAfter = Set(positions.map(PerpetualPositionUniqueIdentifier.init(position:)))
            try PerpetualPosition.deleteAll(db)
            try positions.save(db)
            db.afterNextTransaction { _ in
                NotificationCenter.default.post(
                    onMainThread: Self.perpsPositionDidChangeNotification,
                    object: self,
                    userInfo: [Self.newPositionItemsUserInfoKey: []]
                )
            }
            return positionsBefore != positionsAfter
        }
    }
    
}
