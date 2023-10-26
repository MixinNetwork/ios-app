import Foundation
import GRDB

public final class RawTransactionDAO: UserDatabaseDAO {
    
    public static let shared = RawTransactionDAO()
    
    public func firstRawTransaction() -> RawTransaction? {
        db.select(with: "SELECT * FROM raw_transactions ORDER BY created_at ASC LIMIT 1")
    }
    
}
