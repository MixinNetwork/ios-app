import Foundation

public final class Web3AddressDAO: Web3DAO {
    
    public static let shared = Web3AddressDAO()
    
    public func classicWalletAddress(chainID: String) -> Web3Address? {
        let sql = """
        SELECT a.* FROM addresses a
            INNER JOIN wallets w ON w.wallet_id = a.wallet_id
        WHERE w.category = '\(Web3Wallet.Category.classic.rawValue)'
            AND chain_id = ?
        """
        return db.select(with: sql, arguments: [chainID])
    }
    
    public func address(walletID: String, chainID: String) -> Web3Address? {
        let sql = "SELECT * FROM addresses WHERE wallet_id = ? AND chain_id = ?"
        return db.select(with: sql, arguments: [walletID, chainID])
    }
    
    public func addresses(walletID: String) -> [Web3Address] {
        db.select(with: "SELECT * FROM addresses WHERE wallet_id = ?", arguments: [walletID])
    }
    
    public func allDestinations() -> Set<String> {
        try! db.read { (db) -> Set<String> in
            let sql = "SELECT DISTINCT destination FROM addresses"
            return try String.fetchSet(db, sql: sql)
        }
    }
    
    public func destinations(walletID: String) -> Set<String> {
        try! db.read { (db) -> Set<String> in
            let sql = "SELECT DISTINCT destination FROM addresses WHERE wallet_id = ?"
            return try String.fetchSet(db, sql: sql, arguments: [walletID])
        }
    }
    
    public func save(addresses: [Web3Address]) {
        db.save(addresses)
    }
    
}
