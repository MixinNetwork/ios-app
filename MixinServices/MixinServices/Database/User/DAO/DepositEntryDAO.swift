import Foundation
import GRDB

public final class DepositEntryDAO: UserDatabaseDAO {
    
    public static let shared = DepositEntryDAO()
    
    public func primaryEntry(ofChainWith chainID: String) -> DepositEntry? {
        db.select(where: DepositEntry.column(of: .chainID) == chainID && DepositEntry.column(of: .isPrimary) == true)
    }
    
    public func entries(ofChainWith chainID: String) -> [DepositEntry] {
        db.select(where: DepositEntry.column(of: .chainID) == chainID)
    }
    
    public func save(entries: [DepositEntry], completion: @escaping () -> Void) {
        db.save(entries) { _ in
            completion()
        }
    }
    
}
