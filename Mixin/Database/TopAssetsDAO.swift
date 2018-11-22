import WCDBSwift

final class TopAssetsDAO {
    
    static let shared = TopAssetsDAO()
    static let didChangeNotification = Notification.Name(rawValue: "one.mixin.ios.top.assets.change")
    
    private let sqlQueryAssets = """
    SELECT a1.asset_id, a1.type, a1.symbol, a1.name, a1.icon_url, a1.balance, a1.public_key, a1.price_btc, a1.price_usd, a1.change_usd, a1.chain_id, a2.icon_url as chain_icon_url, a1.confirmations,
        a1.account_name, a1.account_tag
    FROM top_assets a1
    LEFT JOIN assets a2 ON a1.chain_id = a2.asset_id
    WHERE a1.asset_id NOT IN (SELECT asset_id FROM assets)
    """
    
    func getAssets() -> [AssetItem] {
        return MixinDatabase.shared.getCodables(sql: sqlQueryAssets, inTransaction: false)
    }
    
    func insertOrReplaceAssets(_ assets: [Asset]) {
        try? MixinDatabase.shared.database.insertOrReplace(objects: assets, intoTable: Asset.topAssetsTableName)
        NotificationCenter.default.post(name: TopAssetsDAO.didChangeNotification, object: nil)
    }
    
}
