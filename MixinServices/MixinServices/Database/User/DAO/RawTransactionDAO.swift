import Foundation
import GRDB

public final class RawTransactionDAO: UserDatabaseDAO {
    
    public static let shared = RawTransactionDAO()
    
    public func firstRawTransaction() -> RawTransaction? {
        db.select(with: "SELECT * FROM raw_transactions ORDER BY created_at ASC LIMIT 1")
    }
    
    public func deleteAll() {
        db.execute(sql: "DELETE FROM raw_transactions")
    }
    
    public func deleteRawTransaction(with requestID: String) {
        db.execute(sql: "DELETE FROM raw_transactions WHERE request_id = ?", arguments: [requestID])
    }
    
}
