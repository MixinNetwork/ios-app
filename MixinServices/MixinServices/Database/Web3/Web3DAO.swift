import GRDB

public final class Web3DAO {
    
    public static let shared = Web3DAO()
    
    public func greatestNonce(chainID: String) -> Int? {
        let db: Web3Database = .current
        let sql = "SELECT nonce FROM transactions WHERE chain_id = ? ORDER BY nonce DESC LIMIT 1"
        return db.select(with: sql, arguments: [chainID])
    }
    
    public func save(transaction: Web3Transaction) {
        Web3Database.current.save(transaction)
    }
    
}
