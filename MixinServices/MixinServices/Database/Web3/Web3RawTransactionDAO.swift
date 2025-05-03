import Foundation
import GRDB

public final class Web3RawTransactionDAO: Web3DAO {
    
    public static let shared = Web3RawTransactionDAO()
    
    public func pendingRawTransaction(hash: String) -> Web3RawTransaction? {
        db.select(with: """
        SELECT *
        FROM raw_transactions 
        WHERE \(Web3RawTransaction.CodingKeys.state.rawValue) = 'pending'
            AND hash = ?
        """, arguments: [hash])
    }
    
    public func pendingRawTransactions() -> [Web3RawTransaction] {
        db.select(with: """
        SELECT *
        FROM raw_transactions 
        WHERE \(Web3RawTransaction.CodingKeys.state.rawValue) = 'pending'
        """)
    }
    
    public func maxNonce(chainID: String) -> String? {
        db.select(with: """
        SELECT nonce
        FROM raw_transactions 
        WHERE chain_id = ?
            AND \(Web3RawTransaction.CodingKeys.state.rawValue) = 'pending'
        ORDER BY nonce DESC
        LIMIT 1
        """, arguments: [chainID])
    }
    
    public func rawTransactionExists(hash: String) -> Bool {
        db.recordExists(in: Web3RawTransaction.self,
                        where: Web3RawTransaction.column(of: .hash) == hash)
    }
    
    public func pendingRawTransactionsCount(hashIn hashes: [String]) -> Int {
        let query: GRDB.SQL = """
        SELECT COUNT(1)
        FROM raw_transactions
        WHERE state = 'pending'
            AND hash IN \(hashes)
        """
        return db.select(with: query) ?? 0
    }
    
    public func deleteRawTransaction(hash: String, alongsideTransaction change: ((GRDB.Database) throws -> Void)) throws {
        db.write { db in
            try db.execute(
                sql: "DELETE FROM raw_transactions WHERE hash = ?",
                arguments: [hash]
            )
            try change(db)
        }
    }
    
}
