import GRDB

public final class TopAssetsDAO: UserDatabaseDAO {
    
    public static let shared = TopAssetsDAO()
    public static let didChangeNotification = Notification.Name(rawValue: "one.mixin.services.top.assets.change")
    
    public func getAssets() -> [AssetItem] {
        let sql = """
        SELECT a1.asset_id, a1.type, a1.symbol, a1.name, a1.icon_url, a1.balance, a1.destination, a1.tag, a1.price_btc, a1.price_usd, a1.change_usd, a1.chain_id, a2.icon_url as chain_icon_url, a1.confirmations, a1.asset_key, a2.name as chain_name, a2.symbol as chain_symbol, a1.reserve
        FROM top_assets a1
        LEFT JOIN assets a2 ON a1.chain_id = a2.asset_id
        WHERE a1.asset_id NOT IN (SELECT asset_id FROM assets)
        ORDER BY a1.ROWID ASC
        """
        return db.select(with: sql)
    }
    
    public func replaceAssets(_ assets: [TopAsset]) {
        db.write { (db) in
            try TopAsset.deleteAll(db)
            try assets.save(db)
            db.afterNextTransactionCommit { (_) in
                NotificationCenter.default.post(name: TopAssetsDAO.didChangeNotification, object: nil)
            }
        }
    }
    
}
