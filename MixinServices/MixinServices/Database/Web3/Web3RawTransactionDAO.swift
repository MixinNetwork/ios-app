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
    
    public func isExist(hash: String) -> Bool {
        db.recordExists(in: Web3RawTransaction.self,
                        where: Web3RawTransaction.column(of: .hash) == hash)
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
