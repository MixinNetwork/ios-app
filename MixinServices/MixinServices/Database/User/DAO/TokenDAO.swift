import Foundation
import GRDB

public final class TokenDAO: UserDatabaseDAO {
    
    public enum UserInfoKey {
        public static let assetId = "aid"
    }
    
    private enum SQL {
        
        static let selector = """
        SELECT t.asset_id, t.kernel_asset_id, t.symbol, t.name, t.icon_url, t.price_btc, t.price_usd,
            t.chain_id, t.change_usd, t.change_btc, t.dust, t.confirmations, t.asset_key,
            c.icon_url AS chain_icon_url, c.name AS chain_name, c.symbol AS chain_symbol,
            c.threshold AS chain_threshold, c.withdrawal_memo_possibility AS chain_withdrawal_memo_possibility,
            COALESCE(te.balance,'0') AS balance, te.hidden AS hidden
        FROM tokens t
            LEFT JOIN chains c ON t.chain_id = c.chain_id
            LEFT JOIN tokens_extra te ON t.asset_id = te.asset_id
        """
        
        static let order = "te.balance * t.price_usd DESC, cast(te.balance AS REAL) DESC, cast(t.price_usd AS REAL) DESC, t.name ASC, t.rowid DESC"
        
        static let selectWithAssetID = "\(SQL.selector) WHERE t.asset_id = ?"
        
    }
    
    public static let shared = TokenDAO()
    
    public static let tokensDidChangeNotification = NSNotification.Name("one.mixin.services.TokenDAO.TokensDidChange")
    
    public func tokenExists(kernelAssetID: String) -> Bool {
        db.recordExists(in: Token.self, where: Token.column(of: .kernelAssetID) == kernelAssetID)
    }
    
    public func tokenExists(assetID: String) -> Bool {
        db.recordExists(in: Token.self, where: Token.column(of: .assetID) == assetID)
    }
    
    public func assetID(ofAssetWith kernelAssetID: String) -> String? {
        db.select(with: "SELECT asset_id FROM tokens WHERE kernel_asset_id = ?", arguments: [kernelAssetID])
    }
    
    public func tokenItem(with id: String) -> TokenItem? {
        db.select(with: SQL.selectWithAssetID, arguments: [id])
    }
    
    public func search(keyword: String, sortResult: Bool, limit: Int?) -> [TokenItem] {
        var sql = """
        \(SQL.selector)
        WHERE (t.name LIKE :keyword OR t.symbol LIKE :keyword)
        """
        if sortResult {
            sql += " AND te.balance > 0 ORDER BY CASE WHEN t.symbol LIKE :keyword THEN 1 ELSE 0 END DESC, \(SQL.order)"
        }
        if let limit = limit {
            sql += " LIMIT \(limit)"
        }
        return db.select(with: sql, arguments: ["keyword": "%\(keyword)%"])
    }
    
    public func allTokens() -> [TokenItem] {
        db.select(with: "\(SQL.selector) ORDER BY \(SQL.order)")
    }
    
    public func defaultTransferToken() -> TokenItem? {
        if let id = AppGroupUserDefaults.Wallet.defaultTransferAssetId, !id.isEmpty, let token = tokenItem(with: id), token.decimalBalance > 0 {
            return token
        } else {
            let sql = "\(SQL.selector) WHERE te.balance > 0 ORDER BY \(SQL.order) LIMIT 1"
            return UserDatabase.current.select(with: sql)
        }
    }
    
    public func positiveBalancedTokens() -> [TokenItem] {
        db.select(with: "\(SQL.selector) WHERE te.balance > 0 ORDER BY \(SQL.order)")
    }
    
    public func usdBalanceSum() -> Int {
        db.select(with: "SELECT SUM(balance * price_usd) FROM assets") ?? 0
    }
    
    public func save(assets: [Token]) {
        guard !assets.isEmpty else {
            return
        }
        db.save(assets) { _ in
            let center = NotificationCenter.default
            if assets.count == 1 {
                center.post(onMainThread: Self.tokensDidChangeNotification,
                            object: self,
                            userInfo: [Self.UserInfoKey.assetId: assets[0].assetID])
            } else {
                center.post(onMainThread: Self.tokensDidChangeNotification,
                            object: nil)
            }
        }
    }
    
}