import WCDBSwift

final class AssetDAO {

    static let shared = AssetDAO()

    private static let sqlQueryTable = """
    SELECT a1.asset_id, a1.type, a1.symbol, a1.name, a1.icon_url, a1.balance, a1.public_key, a1.price_btc, a1.price_usd, a1.change_usd, a1.chain_id, a2.icon_url as chain_icon_url, a1.confirmations
    FROM assets a1
    LEFT JOIN assets a2 ON a1.chain_id = a2.asset_id
    """
    private static let sqlOrder = "AND NOT (a1.balance = 0 AND a1.asset_id != a1.chain_id) ORDER BY a1.balance * a1.price_usd DESC, a1.price_usd DESC, cast(a1.balance AS REAL) DESC, a1.name DESC"
    private static let sqlQuery = "\(sqlQueryTable) WHERE 1 = 1 \(sqlOrder)"
    private static let sqlQueryAvailable = "\(sqlQueryTable) WHERE a1.balance > 0 \(sqlOrder) LIMIT 1"
    private static let sqlQueryAvailableList = "\(sqlQueryTable) WHERE a1.balance > 0 \(sqlOrder)"
    private static let sqlQuerySearch = "\(sqlQueryTable) WHERE (a1.name like ? OR a1.symbol like ?) \(sqlOrder)"
    private static let sqlQueryById = "\(sqlQueryTable) WHERE a1.asset_id = ?"

    func getChainIconUrl(chainId: String) -> String? {
        return MixinDatabase.shared.scalar(on: Asset.Properties.iconUrl.asColumnResult(), fromTable: Asset.tableName, condition: Asset.Properties.assetId == chainId, inTransaction: false)?.stringValue
    }

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

    func searchAssets(content: String) -> [AssetItem] {
        let keyword = "%\(content)%"
        return MixinDatabase.shared.getCodables(sql: AssetDAO.sqlQuerySearch, values: [keyword, keyword], inTransaction: false)
    }

    func getAssets() -> [AssetItem] {
        return MixinDatabase.shared.getCodables(sql: AssetDAO.sqlQuery, inTransaction: false)
    }

    func getAvailableAssetId(assetId: String?) -> AssetItem? {
        var asset: AssetItem?
        if let assetId = assetId {
            asset = getAsset(assetId: assetId)
        }
        if asset == nil || asset?.balance.toDouble() == 0 {
            let availableAsset: AssetItem? = MixinDatabase.shared.getCodables(sql: AssetDAO.sqlQueryAvailable, inTransaction: false).first
            if availableAsset != nil {
                return availableAsset
            }
        }
        return asset
    }

    func getAvailableAssets() -> [AssetItem] {
        return MixinDatabase.shared.getCodables(sql: AssetDAO.sqlQueryAvailableList, inTransaction: false)
    }

}
