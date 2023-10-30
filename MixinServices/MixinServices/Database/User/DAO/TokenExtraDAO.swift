import Foundation
import GRDB

public final class TokenExtraDAO: UserDatabaseDAO {
    
    public static let shared = TokenExtraDAO()
    
    public func insertOrUpdateBalance(extra: TokenExtra, into db: GRDB.Database) throws {
        let sql = """
        INSERT INTO tokens_extra(
            asset_id, kernel_asset_id, hidden, balance, updated_at
        ) VALUES (
            :asset_id, :kernel_asset_id, :hidden, :balance, :updated_at
        )
        ON CONFLICT(asset_id) DO UPDATE SET balance = :balance
        """
        try db.execute(sql: sql, arguments: [
            "asset_id": extra.assetID,
            "kernel_asset_id": extra.kernelAssetID,
            "hidden": extra.isHidden,
            "balance": extra.balance,
            "updated_at": extra.updatedAt
        ])
    }
    
}
