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
        db.selectSet(with: "SELECT DISTINCT destination FROM addresses")
    }
    
    public func destinations(walletID: String) -> Set<String> {
        db.selectSet(with: "SELECT DISTINCT destination FROM addresses WHERE wallet_id = ?", arguments: [walletID])
    }
    
    public func prettyDestinations(walletID: String) -> String {
        let destinations: [String] = db.select(
            with: "SELECT DISTINCT destination FROM addresses WHERE wallet_id = ?",
            arguments: [walletID]
        )
        return destinations
            .map { destination in
                TextTruncation.truncateMiddle(string: destination, prefixCount: 6, suffixCount: 4)
            }
            .joined(separator: ", ")
    }
    
    public func addressExists(destination: String) -> Bool {
        let id: Int? = db.select(
            with: "SELECT rowid FROM addresses WHERE destination = ?",
            arguments: [destination]
        )
        return id != nil
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
    
    public func save(addresses: [Web3Address]) {
        db.save(addresses)
    }
    
}
