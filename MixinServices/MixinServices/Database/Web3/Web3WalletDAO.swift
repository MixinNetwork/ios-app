import Foundation
import GRDB

public final class Web3WalletDAO: Web3DAO {
    
    public static let shared = Web3WalletDAO()
    
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
            SELECT w.wallet_id, w.category
            FROM wallets w
            ORDER BY w.created_at ASC
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
        
        struct Wallet: Codable, MixinFetchableRecord {
            
            enum CodingKeys: String, CodingKey {
                case walletID = "wallet_id"
                case category
            }
            
            static let databaseTableName = "wallets"
            
            let walletID: String
            let category: String
            
        }
        
        return try! db.read { db in
            let wallets = try Wallet.fetchAll(db, sql: SQL.wallets)
            return try wallets.compactMap { wallet in
                guard wallet.category == Web3Wallet.Category.classic.rawValue else {
                    return nil
                }
                let tokenDigests = try TokenDigest.fetchAll(db, sql: SQL.tokenDigests, arguments: [wallet.walletID])
                return WalletDigest(
                    wallet: .classic(id: wallet.walletID),
                    tokens: tokenDigests
                )
            }
        }
    }
    
    public func save(wallets: [Web3Wallet]) {
        db.save(wallets)
    }
    
}
