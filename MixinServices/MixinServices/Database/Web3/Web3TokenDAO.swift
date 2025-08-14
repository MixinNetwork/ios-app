import Foundation
import GRDB

public final class Web3TokenDAO: Web3DAO {
    
    private enum SQL {
        
        static let selector = """
            SELECT t.*, 
                c.icon_url AS chain_icon_url, c.name AS chain_name, c.symbol AS chain_symbol,
                c.threshold AS chain_threshold, 
                c.withdrawal_memo_possibility AS chain_withdrawal_memo_possibility,
                ifnull(te.hidden,FALSE) AS hidden
            FROM tokens t
                LEFT JOIN chains c ON t.chain_id = c.chain_id
                LEFT JOIN tokens_extra te ON t.wallet_id = te.wallet_id AND t.asset_id = te.asset_id
        """
        
        static let order = """
            ORDER BY t.amount * t.price_usd DESC,
                cast(t.amount AS REAL) DESC,
                cast(t.price_usd AS REAL) DESC,
                t.name ASC,
                t.rowid DESC
        """
        
    }
    
    public static let shared = Web3TokenDAO()
    
    public static let tokensDidChangeNotification = Notification.Name("one.mixin.services.Web3TokenDAO.Change")
    public static let walletIDUserInfoKey = "w"
    
    public func assetID(assetKey: String) -> String? {
        db.select(with: "SELECT asset_id FROM tokens WHERE asset_key = ?", arguments: [assetKey])
    }
    
    public func token(walletID: String, assetID: String) -> Web3TokenItem? {
        let sql = "\(SQL.selector)\nWHERE t.wallet_id = ? AND t.asset_id = ?"
        return db.select(with: sql, arguments: [walletID, assetID])
    }
    
    public func token(walletID: String, assetKey: String) -> Web3TokenItem? {
        let sql = "\(SQL.selector)\nWHERE t.wallet_id = ? AND t.asset_key = ? COLLATE NOCASE"
        return db.select(with: sql, arguments: [walletID, assetKey])
    }
    
    public func greatestBalanceToken(walletID: String, assetIDs: any Collection<String>) -> Web3TokenItem? {
        var query = GRDB.SQL(sql: SQL.selector)
        query.append(literal: " WHERE t.wallet_id = \(walletID) AND t.amount > 0")
        if !assetIDs.isEmpty {
            query.append(literal: " AND t.asset_id IN \(assetIDs)")
        }
        query.append(sql: " ORDER BY t.amount DESC LIMIT 1")
        return db.select(with: query)
    }
    
    public func allTokens() -> [Web3TokenItem] {
        db.select(with: "\(SQL.selector)\n\(SQL.order)")
    }
    
    public func notHiddenTokens(walletID: String) -> [Web3TokenItem] {
        let sql = """
        \(SQL.selector)
        WHERE t.wallet_id = ? AND ifnull(te.hidden,FALSE) IS FALSE
        \(SQL.order)
        """
        return db.select(with: sql, arguments: [walletID])
    }
    
    public func hiddenTokens() -> [Web3TokenItem] {
        let sql = """
        \(SQL.selector)
        WHERE ifnull(te.hidden,FALSE) IS TRUE
        \(SQL.order)
        """
        return db.select(with: sql)
    }
    
    public func tokens(walletID: String, ids: any Collection<String>) -> [Web3Token] {
        guard !ids.isEmpty else {
            return []
        }
        let sql: GRDB.SQL = "SELECT * FROM tokens WHERE wallet_id = \(walletID) AND asset_id IN \(ids)"
        return db.select(with: sql)
    }
    
    public func tokenItems(walletID: String, ids: any Collection<String>) -> [Web3TokenItem] {
        guard !ids.isEmpty else {
            return []
        }
        var query = GRDB.SQL(sql: SQL.selector)
        query.append(literal: "\nWHERE t.wallet_id = \(walletID) AND t.asset_id IN \(ids)")
        return db.select(with: query)
    }
    
    // Key is asset id, value is symbol
    public func tokenSymbols(ids: any Collection<String>) -> [String: String] {
        db.select(
            keyColumn: Web3Token.column(of: .assetID),
            valueColumn: Web3Token.column(of: .symbol),
            from: Web3Token.self,
            where: ids.contains(Web3Token.column(of: .assetID))
        )
    }
    
    public func amount(walletID: String, assetID: String) -> String? {
        db.select(
            with: "SELECT amount FROM tokens WHERE wallet_id = ? AND asset_id = ?",
            arguments: [walletID, assetID]
        )
    }
    
    public func save(tokens: [Web3Token], zeroOutOthers: Bool) {
        guard let walletID = tokens.first?.walletID else {
            return
        }
        db.write { db in
            for token in tokens {
                try token.save(db)
                if token.level < Web3Reputation.Level.unknown.rawValue {
                    let extra = Web3TokenExtra(
                        walletID: token.walletID,
                        assetID: token.assetID,
                        isHidden: true
                    )
                    try extra.insert(db, onConflict: .ignore)
                }
            }
            if zeroOutOthers {
                try db.execute(literal: """
                UPDATE tokens
                SET amount = '0'
                WHERE wallet_id = \(walletID)
                    AND asset_id NOT IN \(tokens.map(\.assetID))
                """)
            }
            db.afterNextTransaction { _ in
                NotificationCenter.default.post(
                    onMainThread: Self.tokensDidChangeNotification,
                    object: self,
                    userInfo: [Self.walletIDUserInfoKey: walletID]
                )
            }
        }
    }
    
}
