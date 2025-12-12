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
    
    public func currentSelectedWallet() -> Web3Wallet? {
        if let id = AppGroupUserDefaults.Wallet.dappConnectionWalletID,
           let wallet: Web3Wallet = db.select(where: Web3Wallet.column(of: .walletID) == id)
        {
            wallet
        } else {
            db.select(where: Web3Wallet.column(of: .category) == Web3Wallet.Category.classic.rawValue)
        }
    }
    
    public func wallets() -> [Web3Wallet] {
        db.select(with: "SELECT * FROM wallets")
    }
    
    public func walletIDs() -> [String] {
        db.select(with: "SELECT wallet_id FROM wallets")
    }
    
    public func walletDigests() -> [WalletDigest] {
        
        enum SQL {
            
            static let wallets = """
            SELECT * FROM wallets ORDER BY created_at ASC
            """
            
            static let hasLegacyAddresses = """
            SELECT TRUE FROM addresses WHERE wallet_id = ? AND path IS NULL
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
            
            static let chains = """
            SELECT DISTINCT chain_id FROM addresses WHERE wallet_id = ?
            """
            
        }
        
        return try! db.read { db in
            try Web3Wallet.fetchAll(db, sql: SQL.wallets).compactMap { wallet in
                let hasLegacyAddress = try Bool.fetchOne(
                    db,
                    sql: SQL.hasLegacyAddresses,
                    arguments: [wallet.walletID]
                ) ?? false
                let tokenDigests = try TokenDigest.fetchAll(
                    db,
                    sql: SQL.tokenDigests,
                    arguments: [wallet.walletID]
                )
                let chainIDs: Set<String>
                switch wallet.category.knownCase {
                case .mixinSafe:
                    chainIDs = if let id = wallet.safeChainID {
                        [id]
                    } else {
                        []
                    }
                default:
                    chainIDs = try String.fetchSet(
                       db,
                       sql: SQL.chains,
                       arguments: [wallet.walletID]
                   )
                }
                return WalletDigest(
                    wallet: .common(wallet),
                    tokens: tokenDigests,
                    supportedChainIDs: chainIDs,
                    hasLegacyAddress: hasLegacyAddress
                )
            }
        }
    }
    
    public func wallet(id: String) -> Web3Wallet? {
        db.select(with: "SELECT * FROM wallets WHERE wallet_id = ?", arguments: [id])
    }
    
    public func wallet(destination: String) -> Web3Wallet? {
        db.select(with: """
        SELECT * FROM wallets w
            INNER JOIN addresses a ON w.wallet_id = a.wallet_id
        WHERE a.destination = ? COLLATE NOCASE
        """, arguments: [destination])
    }
    
    public func walletNames(like template: String) -> [String] {
        db.select(with: "SELECT name FROM wallets WHERE name LIKE ?", arguments: [template])
    }
    
    // Key is address.destination, value is wallet.name
    public func walletNames() -> [String: String] {
        try! db.read { (db) -> [String: String] in
            let sql = """
            SELECT w.name, a.destination
            FROM wallets w
                INNER JOIN addresses a ON w.wallet_id = a.wallet_id
            """
            var names: [String: String] = [:]
            let rows = try Row.fetchCursor(db, sql: sql)
            while let row = try rows.next() {
                guard let destination: String = row["destination"] else {
                    continue
                }
                names[destination] = row["name"]
            }
            return names
        }
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
    
    public func replaceSafeWallets(
        wallets: [Web3Wallet],
        tokens: [Web3Token],
        completion: @escaping () -> Void
    ) {
        db.write { db in
            let walletIDs = try String.fetchAll(
                db,
                sql: "DELETE FROM wallets WHERE category = ? RETURNING wallet_id",
                arguments: [Web3Wallet.Category.mixinSafe.rawValue]
            )
            try db.execute(literal: "DELETE FROM tokens WHERE wallet_id IN \(walletIDs)")
            
            try wallets.save(db)
            try tokens.save(db)
            
            db.afterNextTransaction { _ in
                completion()
            }
        }
    }
    
    public func deleteWallet(id: String) {
        try? db.writeAndReturnError { db in
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
            try db.execute(literal: "DELETE FROM orders WHERE wallet_id = \(id)")
            db.afterNextTransaction { _ in
                NotificationCenter.default.post(
                    onMainThread: Self.walletsDidDeleteNotification,
                    object: self,
                    userInfo: [Self.UserInfoKey.walletID: id]
                )
            }
        }
    }
    
}
