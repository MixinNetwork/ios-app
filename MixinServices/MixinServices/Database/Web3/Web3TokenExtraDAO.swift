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
        let sql = """
        INSERT INTO tokens_extra(
            wallet_id, asset_id, hidden
        ) VALUES (
            :wallet_id, :asset_id, :hidden
        )
        ON CONFLICT(wallet_id, asset_id) DO UPDATE SET hidden = :hidden
        """
        db.write { db in
            try db.execute(sql: sql, arguments: [
                "wallet_id": walletID,
                "asset_id": assetID,
                "hidden": false,
            ])
            db.afterNextTransaction { _ in
                NotificationCenter.default.post(
                    onMainThread: Self.tokenVisibilityDidChangeNotification,
                    object: self
                )
            }
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
