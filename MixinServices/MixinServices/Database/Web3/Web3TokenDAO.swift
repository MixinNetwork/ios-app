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
    
    public func token(walletID: String, assetID: String) -> Web3TokenItem? {
        let sql = "\(SQL.selector)\nWHERE t.wallet_id = ? AND t.asset_id = ?"
        return db.select(with: sql, arguments: [walletID, assetID])
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
    
    public func save(tokens: [Web3Token]) {
        guard let walletID = tokens.first?.walletID else {
            return
        }
        db.save(tokens) { _ in
            NotificationCenter.default.post(
                onMainThread: Self.tokensDidChangeNotification,
                object: self,
                userInfo: [Self.walletIDUserInfoKey: walletID]
            )
        }
    }
    
}
