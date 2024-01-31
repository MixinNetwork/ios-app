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
    
    public func compactEntries() -> [CompactDepositEntry] {
        db.select(with: "SELECT destination, tag FROM deposit_entries")
    }
    
    public func replace(entries: [DepositEntry], forChainWith chainID: String) {
        db.write { db in
            try db.execute(sql: "DELETE FROM deposit_entries WHERE chain_id = ?", arguments: [chainID])
            try entries.save(db)
        }
    }
    
}
