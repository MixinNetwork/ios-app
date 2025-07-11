import Foundation
import GRDB

public final class Web3WalletDAO: Web3DAO {
    
    public enum UserInfoKey {
        static let wallets = "w"
        static let walletID = "id"
    }
    
    public static let shared = Web3WalletDAO()
    
    public static let walletsDidSaveNotification = Notification.Name("one.mixin.services.Web3WalletDAO.Save")
    public static let walletsDidDeleteNotification = Notification.Name("one.mixin.services.Web3WalletDAO.Delete")
    
    public func hasClassicWallet() -> Bool {
        db.recordExists(
            in: Web3Wallet.self,
            where: Web3Wallet.column(of: .category) == Web3Wallet.Category.classic.rawValue
        )
    }
    
    public func hasClassicWallet(id: String) -> Bool {
        db.recordExists(
            in: Web3Wallet.self,
            where: Web3Wallet.column(of: .category) == Web3Wallet.Category.classic.rawValue
                && Web3Wallet.column(of: .walletID) == id
        )
    }
    
    public func classicWallet() -> Web3Wallet? {
        db.select(where: Web3Wallet.column(of: .category) == Web3Wallet.Category.classic.rawValue)
    }
    
    public func walletIDs() -> [String] {
        db.select(with: "SELECT wallet_id FROM wallets")
    }
    
    public func walletDigests() -> [WalletDigest] {
        
        enum SQL {
            
            static let wallets = """
            SELECT * FROM wallets ORDER BY created_at ASC
            """
            
            static let tokenDigests = """
            SELECT t.asset_id, t.symbol, t.name, t.icon_url, t.price_usd, t.amount AS balance
            FROM tokens t
                LEFT JOIN tokens_extra te ON t.wallet_id = te.wallet_id AND t.asset_id = te.asset_id
            WHERE t.wallet_id = ?
                AND ifnull(te.hidden,FALSE) IS FALSE
                AND CAST(t.price_usd * t.amount AS REAL) > 0
            ORDER BY t.price_usd * t.amount DESC
            """
            
        }
        
        return try! db.read { db in
            try Web3Wallet.fetchAll(db, sql: SQL.wallets).compactMap { wallet in
                let tokenDigests = try TokenDigest.fetchAll(
                    db,
                    sql: SQL.tokenDigests,
                    arguments: [wallet.walletID]
                )
                return WalletDigest(
                    wallet: .common(wallet),
                    tokens: tokenDigests
                )
            }
        }
    }
    
    public func wallet(id: String) -> Web3Wallet? {
        db.select(with: "SELECT * FROM wallets WHERE wallet_id = ?", arguments: [id])
    }
    
    public func save(wallets: [Web3Wallet], addresses: [Web3Address]) {
        db.write { db in
            try wallets.save(db)
            try addresses.save(db)
            db.afterNextTransaction { _ in
                NotificationCenter.default.post(
                    onMainThread: Self.walletsDidSaveNotification,
                    object: self,
                    userInfo: [Self.UserInfoKey.wallets: wallets]
                )
            }
        }
    }
    
    // Returns address.destination associated with the wallet
    public func deleteWallet(id: String) -> [String] {
        let destinations = try? db.writeAndReturnError { db in
            try db.execute(literal: "DELETE FROM wallets WHERE wallet_id = \(id)")
            let destinations = try String.fetchAll(
                db,
                sql: "DELETE FROM addresses WHERE wallet_id = ? RETURNING destination",
                arguments: [id]
            )
            try Web3PropertiesDAO.shared.deleteTransactionOffset(
                addresses: destinations,
                db: db
            )
            try db.execute(literal: "DELETE FROM raw_transactions WHERE account IN \(destinations)")
            try db.execute(literal: "DELETE FROM tokens WHERE wallet_id = \(id)")
            try db.execute(literal: "DELETE FROM tokens_extra WHERE wallet_id = \(id)")
            try db.execute(literal: "DELETE FROM transactions WHERE address IN \(destinations)")
            db.afterNextTransaction { _ in
                NotificationCenter.default.post(
                    onMainThread: Self.walletsDidDeleteNotification,
                    object: self,
                    userInfo: [Self.UserInfoKey.walletID: id]
                )
            }
            return destinations
        }
        return destinations ?? []
    }
    
}
