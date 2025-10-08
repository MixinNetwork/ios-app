import Foundation
import GRDB

public final class TokenExtraDAO: UserDatabaseDAO {
    
    public static let shared = TokenExtraDAO()
    
    public static let tokenVisibilityDidChangeNotification = Notification.Name("one.mixin.service.TokenExtraDAO.TokenVisibilityDidChange")
    
    public func tokenExtra(assetID: String) -> TokenExtra? {
        db.select(with: "SELECT * FROM tokens_extra WHERE asset_id = ?", arguments: [assetID])
    }
    
    public func insertOrUpdateBalance(
        extra: TokenExtra,
        into db: GRDB.Database,
        completion: @escaping () -> Void
    ) throws {
        let sql = """
        INSERT INTO tokens_extra(
            asset_id, kernel_asset_id, hidden, balance, updated_at
        ) VALUES (
            :asset_id, :kernel_asset_id, :hidden, :balance, :updated_at
        )
        ON CONFLICT(asset_id) DO UPDATE SET balance = :balance, updated_at = :updated_at
        """
        try db.execute(sql: sql, arguments: [
            "asset_id": extra.assetID,
            "kernel_asset_id": extra.kernelAssetID,
            "hidden": extra.isHidden,
            "balance": extra.balance,
            "updated_at": extra.updatedAt
        ])
        db.afterNextTransaction { _ in
            completion()
        }
    }
    
    public func insertOrUpdateHidden(extra: TokenExtra) {
        let sql = """
        INSERT INTO tokens_extra(
            asset_id, kernel_asset_id, hidden, balance, updated_at
        ) VALUES (
            :asset_id, :kernel_asset_id, :hidden, :balance, :updated_at
        )
        ON CONFLICT(asset_id) DO UPDATE SET hidden = :hidden, updated_at = :updated_at
        """
        db.write { db in
            try db.execute(sql: sql, arguments: [
                "asset_id": extra.assetID,
                "kernel_asset_id": extra.kernelAssetID,
                "hidden": extra.isHidden,
                "balance": extra.balance,
                "updated_at": extra.updatedAt
            ])
            db.afterNextTransaction { _ in
                NotificationCenter.default.post(onMainThread: Self.tokenVisibilityDidChangeNotification, object: self)
            }
        }
    }
    
    public func nullifyAllBalances() {
        db.execute(sql: "UPDATE tokens_extra SET balance = NULL")
    }
    
}
