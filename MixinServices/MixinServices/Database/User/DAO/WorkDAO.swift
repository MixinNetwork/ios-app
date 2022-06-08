import Foundation
import GRDB

public class WorkDAO {
    
    public static let shared = WorkDAO()
    
    public var db: Database {
        UserDatabase.current
    }
    
    public func save(work: PersistedWork) {
        db.write { db in
            try work.save(db)
        }
    }
    
    public func works(with types: [String]) -> [PersistedWork] {
        db.select(where: types.contains(PersistedWork.column(of: .type)),
                  order: [PersistedWork.column(of: .priority).desc])
    }
    
    public func delete(id: String) {
        db.delete(PersistedWork.self, where: PersistedWork.column(of: .id) == id)
    }
    
    public func update(context: Data?, forWorkWith id: String) {
        db.update(PersistedWork.self,
                  assignments: [PersistedWork.column(of: .context).set(to: context)],
                  where: PersistedWork.column(of: .id) == id)
    }
    
}
