import Foundation
import GRDB

public final class Web3RawTransactionDAO: Web3DAO {
    
    public static let shared = Web3RawTransactionDAO()
    
    public func pendingTransactions() -> [Web3RawTransaction] {
        db.select(with: """
            SELECT *
            FROM raw_transactions 
            WHERE \(Web3RawTransaction.CodingKeys.state.rawValue) = 'pending'
        """)
    }
    
    public func deleteTransaction(hash: String) {
        db.write { db in
            let deletePendingTransaction = """
                DELETE FROM transactions
                WHERE \(Web3Transaction.CodingKeys.status.rawValue) = 'pending'
                    AND transaction_hash = ?
            """
            try db.execute(sql: deletePendingTransaction, arguments: [hash])
            
            let deleteRawTransaction = "DELETE FROM raw_transactions WHERE hash = ?"
            try db.execute(sql: deleteRawTransaction, arguments: [hash])
        }
    }
    
    public func save(rawTransaction: Web3RawTransaction, pendingTransaction: Web3Transaction) {
        db.write { db in
            try rawTransaction.save(db)
            try pendingTransaction.save(db)
        }
    }
    
}
