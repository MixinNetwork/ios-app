import Foundation

public final class Web3AddressDAO: Web3DAO {
    
    public static let shared = Web3AddressDAO()
    
    public func address(walletID: String, chainID: String) -> Web3Address? {
        let sql = "SELECT * FROM addresses WHERE wallet_id = ? AND chain_id = ?"
        return db.select(with: sql, arguments: [walletID, chainID])
    }
    
    public func save(addresses: [Web3Address]) {
        db.save(addresses)
    }
    
}
