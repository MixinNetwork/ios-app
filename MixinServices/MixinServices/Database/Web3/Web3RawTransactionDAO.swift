import Foundation
import GRDB

public final class Web3RawTransactionDAO: Web3DAO {
    
    public static let shared = Web3RawTransactionDAO()
    
    public func save(rawTransaction: Web3RawTransaction) {
        db.save(rawTransaction)
    }
    
    public func save(rawTransaction: Web3RawTransaction, pendingTransaction: Web3Transaction) {
        db.write { db in
            try rawTransaction.save(db)
            try pendingTransaction.save(db)
        }
    }
    
}
