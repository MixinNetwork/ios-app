import Foundation
import GRDB

extension Array where Element: PersistableRecord {
    
    public func save(_ db: GRDB.Database) throws {
        for record in self {
            try record.save(db)
        }
    }
    
    public func insert(
        _ db: GRDB.Database,
        onConflict conflictResolution: GRDB.Database.ConflictResolution? = nil
    ) throws {
        for record in self {
            try record.insert(db, onConflict: conflictResolution)
        }
    }
    
}
