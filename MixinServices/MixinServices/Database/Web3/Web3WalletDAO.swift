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
            
            static let topTokenDigests = """
            SELECT t.asset_id, t.symbol, t.name, t.icon_url, t.price_usd, t.amount AS balance
            FROM tokens t
            WHERE t.wallet_id = ?
                AND CAST(t.price_usd * t.amount AS REAL) > 0
            ORDER BY t.price_usd * t.amount DESC
            LIMIT ?
            """
            
            static let positiveUSDBalanceTokensCount = """
            SELECT COUNT(1)
            FROM tokens t
            WHERE t.wallet_id = ?
                AND CAST(t.price_usd * t.amount AS REAL) > 0
            """
            
            static let usdBalanceSum = """
            SELECT SUM(ifnull(t.amount,'0') * t.price_usd)
            FROM tokens t
            WHERE t.wallet_id = ?
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
                let topTokenDigests = try TokenDigest.fetchAll(db, sql: SQL.topTokenDigests, arguments: [wallet.walletID, 5])
                let positiveUSDBalanceTokensCount = try Int.fetchOne(db, sql: SQL.positiveUSDBalanceTokensCount, arguments: [wallet.walletID]) ?? 0
                let usdBalanceSum = try Decimal.fetchOne(db, sql: SQL.usdBalanceSum, arguments: [wallet.walletID]) ?? 0
                return WalletDigest(
                    wallet: .classic(id: wallet.walletID),
                    usdBalanceSum: usdBalanceSum,
                    tokens: topTokenDigests,
                    positiveUSDBalanceTokensCount: positiveUSDBalanceTokensCount
                )
            }
        }
    }
    
    public func save(wallets: [Web3Wallet]) {
        db.save(wallets)
    }
    
}
