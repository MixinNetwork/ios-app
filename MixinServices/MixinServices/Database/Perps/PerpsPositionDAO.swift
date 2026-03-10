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
        LEFT JOIN markets m ON p.product_id = m.market_id
    
    """
    
    public func position(productID: String) -> PerpetualPositionItem? {
        db.select(with: Self.itemSQL + "WHERE p.product_id = ?", arguments: [productID])
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
