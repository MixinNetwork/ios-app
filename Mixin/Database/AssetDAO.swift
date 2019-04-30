import WCDBSwift

final class AssetDAO {

    static let shared = AssetDAO()

    private static let sqlQueryTable = """
    SELECT a1.asset_id, a1.type, a1.symbol, a1.name, a1.icon_url, a1.balance, a1.public_key, a1.price_btc, a1.price_usd, a1.change_usd, a1.chain_id, a2.icon_url as chain_icon_url, a1.confirmations,
        a1.account_name, a1.account_tag, a1.asset_key, a2.name as chain_name
    FROM assets a1
    LEFT JOIN assets a2 ON a1.chain_id = a2.asset_id
    """
    private static let sqlOrder = "ORDER BY a1.balance * a1.price_usd DESC, a1.price_usd DESC, cast(a1.balance AS REAL) DESC, a1.name DESC"
    private static let sqlQuery = "\(sqlQueryTable) WHERE 1 = 1 \(sqlOrder)"
    private static let sqlQueryAvailable = "\(sqlQueryTable) WHERE a1.balance > 0 \(sqlOrder) LIMIT 1"
    private static let sqlQueryAvailableList = "\(sqlQueryTable) WHERE a1.balance > 0 \(sqlOrder)"
    private static let sqlQuerySearch = "\(sqlQueryTable) WHERE a1.balance > 0 AND (a1.name like ? OR a1.symbol like ?) \(sqlOrder)"
    private static let sqlQueryById = "\(sqlQueryTable) WHERE a1.asset_id = ?"

    func getAsset(assetId: String) -> AssetItem? {
        return MixinDatabase.shared.getCodables(on: AssetItem.Properties.all, sql: AssetDAO.sqlQueryById, values: [assetId], inTransaction: false).first
    }

    func isExist(assetId: String) -> Bool {
        return MixinDatabase.shared.isExist(type: Asset.self, condition: Asset.Properties.assetId == assetId, inTransaction: false)
    }

    func insertOrUpdateAssets(assets: [Asset]) {
        guard assets.count > 0 else {
            return
        }
        MixinDatabase.shared.insertOrReplace(objects: assets)
        if assets.count == 1 {
            NotificationCenter.default.afterPostOnMain(name: .AssetsDidChange, object: assets[0].assetId)
        } else {
            NotificationCenter.default.afterPostOnMain(name: .AssetsDidChange)
        }
    }
    
    func getAssets(keyword: String, limit: Int?) -> [AssetItem] {
        let keyword = "%\(keyword)%"
        var sql = AssetDAO.sqlQuerySearch
        if let limit = limit {
            sql += " LIMIT \(limit)"
        }
        return MixinDatabase.shared.getCodables(sql: sql, values: [keyword, keyword], inTransaction: false)
    }
    
    func getAssets() -> [AssetItem] {
        return MixinDatabase.shared.getCodables(sql: AssetDAO.sqlQuery, inTransaction: false)
    }

    func getDefaultTransferAsset() -> AssetItem? {
        if let assetId = WalletUserDefault.shared.defalutTransferAssetId, let asset = getAsset(assetId: assetId), asset.balance.doubleValue > 0 {
            return asset
        }
        if let availableAsset: AssetItem = MixinDatabase.shared.getCodables(sql: AssetDAO.sqlQueryAvailable, inTransaction: false).first {
            return availableAsset
        }
        return nil
    }

    func getAvailableAssets() -> [AssetItem] {
        return MixinDatabase.shared.getCodables(sql: AssetDAO.sqlQueryAvailableList, inTransaction: false)
    }

}
