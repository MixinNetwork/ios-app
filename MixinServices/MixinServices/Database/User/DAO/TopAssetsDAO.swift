import GRDB

public final class TopAssetsDAO: UserDatabaseDAO {
    
    public static let shared = TopAssetsDAO()
    public static let didChangeNotification = Notification.Name(rawValue: "one.mixin.services.top.assets.change")
    
    public func getAssets() -> [AssetItem] {
        let sql = """
        SELECT a.asset_id, a.type, a.symbol, a.name, a.icon_url, a.balance, a.destination, a.tag, a.price_btc,
            a.price_usd, a.change_usd, a.chain_id, a.confirmations, a.asset_key, a.reserve, NULL AS deposit_entries,
            a.withdrawal_memo_possibility,
            c.icon_url as chainIconUrl, c.name as chainName, c.symbol as chainSymbol, c.chain_id as chainId, c.threshold as chainThreshold
        FROM top_assets a
        LEFT JOIN chains c ON a.chain_id = c.chain_id
        WHERE a.asset_id NOT IN (SELECT asset_id FROM assets)
        ORDER BY a.ROWID ASC
        """
        return db.select(with: sql)
    }
    
    public func replaceAssets(_ assets: [TopAsset]) {
        db.write { (db) in
            try TopAsset.deleteAll(db)
            try assets.save(db)
            db.afterNextTransaction { (_) in
                NotificationCenter.default.post(name: TopAssetsDAO.didChangeNotification, object: nil)
            }
        }
    }
    
}
