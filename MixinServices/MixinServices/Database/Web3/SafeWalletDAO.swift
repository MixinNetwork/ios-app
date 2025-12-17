import Foundation
import GRDB

public final class SafeWalletDAO: Web3DAO {
    
    public static let shared = SafeWalletDAO()
    
    public func hasSafeWallet(chainID: String) -> Bool {
        let value: Int? = db.select(
            with: "SELECT 1 FROM safe_wallets WHERE chain_id = ?",
            arguments: [chainID]
        )
        return (value ?? 0) != 0
    }
    
    public func wallet(safeAddress: String) -> SafeWallet? {
        db.select(
            with: "SELECT * FROM safe_wallets WHERE address = ?",
            arguments: [safeAddress]
        )
    }
    
    public func walletDigests() -> [WalletDigest] {
        try! db.read { db in
            try SafeWallet.fetchAll(db, sql: "SELECT * FROM safe_wallets").map { wallet in
                let tokenDigests = try TokenDigest.fetchAll(
                    db,
                    sql: Web3TokenDAO.SQL.tokenDigests,
                    arguments: [wallet.walletID]
                )
                return WalletDigest(
                    wallet: .safe(wallet),
                    tokens: tokenDigests,
                    supportedChainIDs: [wallet.chainID],
                    hasLegacyAddress: false
                )
            }
        }
    }
    
    public func replace(
        wallets: [SafeWallet],
        tokens: [Web3Token],
        completion: @escaping () -> Void
    ) {
        db.write { db in
            let walletIDs = try String.fetchAll(
                db,
                sql: "DELETE FROM safe_wallets RETURNING wallet_id",
            )
            try db.execute(literal: "DELETE FROM tokens WHERE wallet_id IN \(walletIDs)")
            
            try wallets.save(db)
            try tokens.save(db)
            
            db.afterNextTransaction { _ in
                completion()
            }
        }
    }
    
}
