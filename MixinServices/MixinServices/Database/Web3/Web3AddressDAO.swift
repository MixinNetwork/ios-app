import Foundation
import GRDB

public final class Web3AddressDAO: Web3DAO {
    
    public static let shared = Web3AddressDAO()
    
    public func currentSelectedWalletAddress(chainID: String) -> Web3Address? {
        if let walletID = AppGroupUserDefaults.Wallet.dappConnectionWalletID {
            db.select(with: """
            SELECT a.* FROM addresses a
                INNER JOIN wallets w ON w.wallet_id = a.wallet_id
            WHERE w.wallet_id = ? AND chain_id = ?
            """, arguments: [walletID, chainID])
        } else {
            db.select(with: """
            SELECT a.* FROM addresses a
                INNER JOIN wallets w ON w.wallet_id = a.wallet_id
            WHERE w.category = '\(Web3Wallet.Category.classic.rawValue)'
                AND chain_id = ?
            """, arguments: [chainID])
        }
    }
    
    public func address(walletID: String, chainID: String) -> Web3Address? {
        let sql = "SELECT * FROM addresses WHERE wallet_id = ? AND chain_id = ?"
        return db.select(with: sql, arguments: [walletID, chainID])
    }
    
    public func addresses(walletID: String) -> [Web3Address] {
        db.select(with: "SELECT * FROM addresses WHERE wallet_id = ?", arguments: [walletID])
    }
    
    public func destination(
        walletID: String,
        chainID: String,
        db: GRDB.Database
    ) throws -> String? {
        try String.fetchOne(
            db,
            sql: "SELECT destination FROM addresses WHERE wallet_id = ? AND chain_id = ?",
            arguments: [walletID, chainID]
        )
    }
    
    public func allDestinations() -> Set<String> {
        db.selectSet(with: "SELECT DISTINCT destination FROM addresses")
    }
    
    public func destinations(walletID: String) -> Set<String> {
        db.selectSet(with: "SELECT DISTINCT destination FROM addresses WHERE wallet_id = ?", arguments: [walletID])
    }
    
    public func chainIDs(walletID: String) -> Set<String> {
        db.selectSet(with: "SELECT DISTINCT chain_id FROM addresses WHERE wallet_id = ?", arguments: [walletID])
    }
    
    public func networks(walletID: String) -> [Web3WalletNetwork] {
        let sql = """
        SELECT c.name, c.chain_id, c.icon_url, a.path, a.destination
        FROM addresses a
            INNER JOIN chains c ON a.chain_id = c.chain_id
        WHERE a.wallet_id = ?
        """
        return db.select(with: sql, arguments: [walletID])
    }
    
    public func paths(walletCategory: Web3Wallet.Category) -> [String] {
        let paths: [String?] = db.select(
            with: """
            SELECT a.path FROM addresses a
                INNER JOIN wallets w ON w.wallet_id = a.wallet_id
            WHERE w.category = ?
            """,
            arguments: [walletCategory.rawValue]
        )
        return paths.compactMap({ $0 })
    }
    
    public func save(addresses: [Web3Address]) {
        db.save(addresses)
    }
    
}
