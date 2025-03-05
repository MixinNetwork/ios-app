import Foundation
import GRDB

public final class Web3TokenDAO: Web3DAO {
    
    public static let shared = Web3TokenDAO()
    
    public static let tokensDidChangeNotification = Notification.Name("one.mixin.services.Web3TokenDAO.Change")
    public static let walletIDUserInfoKey = "w"
    
    public func tokens(walletID: String) -> [Web3Token] {
        db.select(with: "SELECT * FROM tokens WHERE wallet_id = ?", arguments: [walletID])
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
