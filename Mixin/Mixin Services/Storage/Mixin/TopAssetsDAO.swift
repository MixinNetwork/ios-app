import WCDBSwift

public final class TopAssetsDAO {
    
    public static let shared = TopAssetsDAO()
    public static let didChangeNotification = Notification.Name(rawValue: "one.mixin.services.top.assets.change")
    
    private let sqlQueryAssets = """
    SELECT a1.asset_id, a1.type, a1.symbol, a1.name, a1.icon_url, a1.balance, a1.destination, a1.tag, a1.price_btc, a1.price_usd, a1.change_usd, a1.chain_id, a2.icon_url as chain_icon_url, a1.confirmations, a1.asset_key, a2.name as chain_name
    FROM top_assets a1
    LEFT JOIN assets a2 ON a1.chain_id = a2.asset_id
    WHERE a1.asset_id NOT IN (SELECT asset_id FROM assets)
    ORDER BY a1.ROWID ASC
    """
    
    public func getAssets() -> [AssetItem] {
        return MixinDatabase.shared.getCodables(sql: sqlQueryAssets)
    }
    
    public func replaceAssets(_ assets: [Asset]) {
        MixinDatabase.shared.transaction { (db) in
            try db.delete(fromTable: Asset.topAssetsTableName)
            try db.insert(objects: assets, intoTable: Asset.topAssetsTableName)
        }
        NotificationCenter.default.post(name: TopAssetsDAO.didChangeNotification, object: nil)
    }
    
}
