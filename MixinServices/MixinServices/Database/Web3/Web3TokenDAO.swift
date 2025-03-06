import Foundation
import GRDB

public final class Web3TokenDAO: Web3DAO {
    
    public static let shared = Web3TokenDAO()
    
    public static let tokensDidChangeNotification = Notification.Name("one.mixin.services.Web3TokenDAO.Change")
    public static let walletIDUserInfoKey = "w"
    
    public func notHiddenTokens(walletID: String) -> [Web3TokenItem] {
        db.select(with: selectTokenSQL(condition: "t.wallet_id = ? AND ifnull(te.hidden,FALSE) IS FALSE"), arguments: [walletID])
    }
    
    public func hiddenTokens() -> [Web3TokenItem] {
        db.select(with: selectTokenSQL(condition: "ifnull(te.hidden,FALSE) IS TRUE"))
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
    
    private func selectTokenSQL(condition: String) -> String {
        """
        SELECT t.*, ifnull(te.hidden,FALSE) AS hidden
        FROM tokens t
            LEFT JOIN tokens_extra te ON t.wallet_id = te.wallet_id AND t.asset_id = te.asset_id
        WHERE \(condition)
        ORDER BY t.amount * t.price_usd DESC,
            cast(t.amount AS REAL) DESC,
            cast(t.price_usd AS REAL) DESC,
            t.name ASC,
            t.rowid DESC
        """
    }
    
}
