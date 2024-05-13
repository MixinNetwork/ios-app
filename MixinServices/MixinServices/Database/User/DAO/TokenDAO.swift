import Foundation
import GRDB

public final class TokenDAO: UserDatabaseDAO {
    
    public enum UserInfoKey {
        public static let assetId = "aid"
    }
    
    private enum SQL {
        
        static let columns = """
            SELECT t.asset_id, t.kernel_asset_id, t.symbol, t.name, t.icon_url, t.price_btc, t.price_usd,
                t.chain_id, t.change_usd, t.change_btc, t.dust, t.confirmations, t.asset_key,
                t.collection_hash, c.icon_url AS chain_icon_url, c.name AS chain_name, c.symbol AS chain_symbol,
                c.threshold AS chain_threshold, c.withdrawal_memo_possibility AS chain_withdrawal_memo_possibility,
                ifnull(te.balance,'0') AS balance, ifnull(te.hidden,FALSE) AS hidden
            FROM tokens t
                LEFT JOIN chains c ON t.chain_id = c.chain_id
                LEFT JOIN tokens_extra te ON t.asset_id = te.asset_id
        """
        
        static let tokenSelector = columns + "\nWHERE t.collection_hash IS NULL"
        
        static let order = "te.balance * t.price_usd DESC, cast(te.balance AS REAL) DESC, cast(t.price_usd AS REAL) DESC, t.name ASC, t.rowid DESC"
        
        static let selectWithAssetID = "\(SQL.tokenSelector) AND t.asset_id = ?"
        
    }
    
    public static let shared = TokenDAO()
    
    public static let tokensDidChangeNotification = NSNotification.Name("one.mixin.services.TokenDAO.TokensDidChange")
    
    public func tokenExists(assetID: String) -> Bool {
        db.recordExists(in: Token.self, where: Token.column(of: .assetID) == assetID)
    }
    
    public func inexistAssetIDs(in assetIDs: [String]) -> [String] {
        let values = assetIDs.map({ "('\($0)')" }).joined(separator: ",")
        return db.select(with: """
          WITH q(id) AS (VALUES \(values))
          SELECT q.id FROM q LEFT JOIN tokens t ON q.id = t.asset_id WHERE t.asset_id IS NULL
        """)
    }
    
    public func assetID(ofAssetWith kernelAssetID: String) -> String? {
        db.select(with: "SELECT asset_id FROM tokens WHERE kernel_asset_id = ?", arguments: [kernelAssetID])
    }
    
    public func chainID(ofAssetWith assetID: String) -> String? {
        db.select(with: "SELECT chain_id FROM tokens WHERE asset_id = ?", arguments: [assetID])
    }
    
    public func tokenItem(assetID: String) -> TokenItem? {
        db.select(with: SQL.selectWithAssetID, arguments: [assetID])
    }
    
    public func tokenItems(with ids: [String]) -> [TokenItem] {
        let ids = ids.joined(separator: "','")
        return db.select(with: "\(SQL.tokenSelector) AND t.asset_id IN ('\(ids)')")
    }
    
    public func inscriptionToken(inscriptionHash: String) -> TokenItem? {
        try! db.read { (db) -> TokenItem? in
            let outputSQL = "SELECT * FROM outputs WHERE inscription_hash = ? LIMIT 1"
            let output = try Output.fetchOne(db, sql: outputSQL, arguments: [inscriptionHash])
            guard let output else {
                return nil
            }
            let tokenSQL = SQL.columns + "\nWHERE t.kernel_asset_id = ?"
            guard let token = try TokenItem.fetchOne(db, sql: tokenSQL, arguments: [output.asset]) else {
                return nil
            }
            return TokenItem(token: token, balance: output.amount, isHidden: false, chain: token.chain)
        }
    }
    
    public func tokens(limit: Int, after assetId: String?) -> [Token] {
        var sql = "SELECT * FROM tokens WHERE collection_hash IS NULL"
        if let assetId {
            sql += " AND ROWID > IFNULL((SELECT ROWID FROM tokens WHERE asset_id = '\(assetId)'), 0)"
        }
        sql += " ORDER BY ROWID LIMIT ?"
        return db.select(with: sql, arguments: [limit])
    }
    
    public func tokensCount() -> Int {
        let count: Int? = db.select(with: "SELECT COUNT(*) FROM tokens")
        return count ?? 0
    }
    
    public func search(keyword: String, sortResult: Bool, limit: Int?) -> [TokenItem] {
        var sql = """
        \(SQL.tokenSelector)
        AND (t.name LIKE :keyword OR t.symbol LIKE :keyword)
        """
        if sortResult {
            sql += " AND te.balance > 0 ORDER BY CASE WHEN t.symbol LIKE :keyword THEN 1 ELSE 0 END DESC, \(SQL.order)"
        }
        if let limit = limit {
            sql += " LIMIT \(limit)"
        }
        return db.select(with: sql, arguments: ["keyword": "%\(keyword)%"])
    }
    
    public func allAssetIDs() -> [String] {
        db.select(with: "SELECT asset_id FROM tokens WHERE collection_hash IS NULL")
    }
    
    public func allTokens() -> [TokenItem] {
        db.select(with: "\(SQL.tokenSelector) ORDER BY \(SQL.order)")
    }
    
    public func hiddenTokens() -> [TokenItem] {
        db.select(with: "\(SQL.tokenSelector) AND ifnull(te.hidden,FALSE) IS TRUE ORDER BY \(SQL.order)")
    }
    
    public func notHiddenTokens() -> [TokenItem] {
        db.select(with: "\(SQL.tokenSelector) AND ifnull(te.hidden,FALSE) IS FALSE ORDER BY \(SQL.order)")
    }
    
    public func defaultTransferToken() -> TokenItem? {
        if let id = AppGroupUserDefaults.Wallet.defaultTransferAssetId, !id.isEmpty, let token = tokenItem(assetID: id), token.decimalBalance > 0 {
            return token
        } else {
            let sql = "\(SQL.tokenSelector) AND te.balance > 0 ORDER BY \(SQL.order) LIMIT 1"
            return UserDatabase.current.select(with: sql)
        }
    }
    
    public func positiveBalancedTokens(chainIDs: [String] = []) -> [TokenItem] {
        var sql = "\(SQL.tokenSelector) AND te.balance > 0"
        if !chainIDs.isEmpty {
            sql += " AND t.chain_id IN ('\(chainIDs.joined(separator: "','"))')"
        }
        sql += " ORDER BY \(SQL.order)"
        return db.select(with: sql)
    }
    
    public func appTokens(ids: [String]) -> [AppToken] {
        var query: GRDB.SQL = """
            SELECT t.asset_id, ifnull(te.balance,'0') AS balance, t.chain_id, t.symbol, t.name, t.icon_url
            FROM tokens t
                LEFT JOIN tokens_extra te ON t.asset_id = te.asset_id
            WHERE t.collection_hash IS NULL
        """
        if !ids.isEmpty {
            query.append(literal: " AND t.asset_id IN \(ids)")
        }
        return try! db.read { (db: GRDB.Database) -> [AppToken] in
            let (sql, arguments) = try query.build(db)
            return try AppToken.fetchAll(db, sql: sql, arguments: arguments)
        }
    }
    
    public func usdBalanceSum() -> Int {
        db.select(with: "SELECT SUM(balance * price_usd) FROM assets") ?? 0
    }
    
    public func save(assets: [Token], completion: (() -> Void)? = nil) {
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
            completion?()
        }
    }
    
    public func save(token: Token) {
        db.save(token)
    }
    
    public func saveAndFetch(token: Token) -> TokenItem? {
        try! db.writeAndReturnError { db in
            try token.save(db)
            return try TokenItem.fetchOne(db, sql: SQL.selectWithAssetID, arguments: [token.assetID])
        }
    }
    
}
