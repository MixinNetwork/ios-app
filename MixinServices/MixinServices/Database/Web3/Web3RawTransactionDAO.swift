import Foundation
import GRDB

public final class Web3RawTransactionDAO: Web3DAO {
    
    public static let shared = Web3RawTransactionDAO()
    
    public func pendingRawTransactions() -> [Web3RawTransaction] {
        db.select(with: """
            SELECT *
            FROM raw_transactions 
            WHERE \(Web3RawTransaction.CodingKeys.state.rawValue) = 'pending'
        """)
    }
    
    public func deleteRawTransaction(hash: String, db: GRDB.Database) throws {
        try db.execute(
            sql: "DELETE FROM raw_transactions WHERE hash = ?",
            arguments: [hash]
        )
    }
    
}
