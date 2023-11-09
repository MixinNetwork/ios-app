import Foundation
import GRDB

public final class TokenExtraDAO: UserDatabaseDAO {
    
    public static let shared = TokenExtraDAO()
    
    public static let tokenVisibilityDidChangeNotification = Notification.Name("one.mixin.messenger.service.TokenVisibilityDidChange")
    
    public func insertOrUpdateBalance(extra: TokenExtra, into db: GRDB.Database) throws {
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
