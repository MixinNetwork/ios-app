import Foundation

public final class Web3TokenExtraDAO: Web3DAO {
    
    public static let shared = Web3TokenExtraDAO()
    
    public static let tokenVisibilityDidChangeNotification = Notification.Name("one.mixin.service.Web3TokenExtraDAO.TokenVisibilityDidChange")
    
    public func isHidden(walletID: String, assetID: String) -> Bool {
        db.select(
            with: "SELECT hidden FROM tokens_extra WHERE wallet_id = ? AND asset_id = ?",
            arguments: [walletID, assetID]
        ) ?? false
    }
    
    public func unhide(walletID: String, assetID: String) {
        db.execute(
            sql: "DELETE FROM tokens_extra WHERE wallet_id = ? AND asset_id = ?",
            arguments: [walletID, assetID]
        ) { _ in
            NotificationCenter.default.post(
                onMainThread: Self.tokenVisibilityDidChangeNotification,
                object: self
            )
        }
    }
    
    public func hide(walletID: String, assetID: String) {
        let extra = Web3TokenExtra(walletID: walletID, assetID: assetID, isHidden: true)
        db.save(extra) { _ in
            NotificationCenter.default.post(
                onMainThread: Self.tokenVisibilityDidChangeNotification,
                object: self
            )
        }
    }
    
}
