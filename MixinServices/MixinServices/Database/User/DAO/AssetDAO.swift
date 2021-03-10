import Foundation
import GRDB

public final class AssetDAO: UserDatabaseDAO {
    
    public enum UserInfoKey {
        public static let assetId = "aid"
    }
    
    public static let shared = AssetDAO()
    
    public static let assetsDidChangeNotification = NSNotification.Name("one.mixin.services.AssetDAO.assetsDidChange")
    
    private static let sqlQueryTable = """
    SELECT a.asset_id, a.type, a.symbol, a.name, a.icon_url, a.balance, a.destination, a.tag,
        a.price_btc, a.price_usd, a.change_usd, a.chain_id, a.confirmations, a.asset_key, a.reserve,
        chain.icon_url as chain_icon_url, chain.name as chain_name, chain.symbol as chain_symbol
    FROM assets a
    LEFT JOIN assets chain ON a.chain_id = chain.asset_id
    """
    private static let sqlOrder = "a.balance * a.price_usd DESC, a.price_usd DESC, cast(a.balance AS REAL) DESC, a.name DESC"
    private static let sqlQuery = "\(sqlQueryTable) ORDER BY \(sqlOrder)"
    private static let sqlQueryAvailable = "\(sqlQueryTable) WHERE a.balance > 0 ORDER BY \(sqlOrder) LIMIT 1"
    private static let sqlQueryAvailableList = "\(sqlQueryTable) WHERE a.balance > 0 ORDER BY \(sqlOrder)"
    
    private static let sqlQueryById = "\(sqlQueryTable) WHERE a.asset_id = ?"
    
    public func getAsset(assetId: String) -> AssetItem? {
        db.select(with: AssetDAO.sqlQueryById, arguments: [assetId])
    }
    
    public func getAssetIds() -> [String] {
        db.select(column: Asset.column(of: .assetId), from: Asset.self)
    }
    
    public func isExist(assetId: String) -> Bool {
        db.recordExists(in: Asset.self, where: Asset.column(of: .assetId) == assetId)
    }
    
    public func insertOrUpdateAssets(assets: [Asset]) {
        guard !assets.isEmpty else {
            return
        }
        db.save(assets) { _ in
            let center = NotificationCenter.default
            if assets.count == 1 {
                center.post(onMainThread: Self.assetsDidChangeNotification,
                            object: self,
                            userInfo: [Self.UserInfoKey.assetId: assets[0].assetId])
            } else {
                center.post(onMainThread: Self.assetsDidChangeNotification,
                            object: nil)
            }
        }
    }
    
    public func saveAsset(asset: Asset) -> AssetItem? {
        var assetItem: AssetItem?
        try db.save(asset) { db in
            assetItem = try! AssetItem.fetchOne(db,
                                                sql: AssetDAO.sqlQueryById,
                                                arguments: [asset.assetId],
                                                adapter: nil)
        }
        return assetItem
    }
    
    public func getAssets(keyword: String, sortResult: Bool, limit: Int?) -> [AssetItem] {
        var sql = """
        \(Self.sqlQueryTable)
        WHERE (a.name LIKE :keyword OR a.symbol LIKE :keyword)
        """
        if sortResult {
            sql += " AND a.balance > 0 ORDER BY CASE WHEN a.symbol LIKE :keyword THEN 1 ELSE 0 END DESC, \(Self.sqlOrder)"
        }
        if let limit = limit {
            sql += " LIMIT \(limit)"
        }
        return db.select(with: sql, arguments: ["keyword": "%\(keyword)%"])
    }
    
    public func getAssets() -> [AssetItem] {
        db.select(with: AssetDAO.sqlQuery)
    }
    
    public func getDefaultTransferAsset() -> AssetItem? {
        if let assetId = AppGroupUserDefaults.Wallet.defaultTransferAssetId, !assetId.isEmpty, let asset = getAsset(assetId: assetId), asset.balance.doubleValue > 0 {
            return asset
        }
        return UserDatabase.current.select(with: AssetDAO.sqlQueryAvailable)
    }
    
    public func getAvailableAssets() -> [AssetItem] {
        db.select(with: AssetDAO.sqlQueryAvailableList)
    }
    
    public func getTotalUSDBalance() -> Int {
        db.select(with: "SELECT SUM(balance * price_usd) FROM assets") ?? 0
    }
    
}
