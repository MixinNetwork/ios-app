import Foundation
import GRDB

public final class RawTransactionDAO: UserDatabaseDAO {
    
    public static let shared = RawTransactionDAO()
    
    public func unspentRawTransactionCount(types: Set<RawTransaction.TransactionType>) -> Int {
        let types = types.map({ "\($0.rawValue)" }).joined(separator: ",")
        let count: Int? = db.select(with: "SELECT count(1) FROM raw_transactions WHERE state = 'unspent' AND type IN (\(types))")
        return count ?? 0
    }
    
    public func firstUnspentRawTransaction(types: Set<RawTransaction.TransactionType>) -> RawTransaction? {
        let types = types.map({ "\($0.rawValue)" }).joined(separator: ",")
        return db.select(with: "SELECT * FROM raw_transactions WHERE state = 'unspent' AND type IN (\(types)) ORDER BY created_at ASC, rowid ASC LIMIT 1")
    }
    
    public func rawTransaction(with requestID: String) -> RawTransaction? {
        db.select(with: "SELECT * FROM raw_transactions WHERE request_id = ?", arguments: [requestID])
    }
    
    public func signRawTransactions(with requestIDs: [String]) {
        db.write { db in
            let ids = requestIDs.joined(separator: "','")
            try db.execute(sql: "UPDATE raw_transactions SET state = ? WHERE request_id IN ('\(ids)')",
                           arguments: [RawTransaction.State.signed.rawValue])
        }
    }
    
    public func deleteAll() {
        db.execute(sql: "DELETE FROM raw_transactions")
    }
    
}
