import Foundation
import GRDB

public final class PropertiesDAO: UserDatabaseDAO {
    
    public enum Key: String {
        case iterator
        case snapshotOffset = "snapshot_offset"
    }
    
    public static let shared = PropertiesDAO()
    
    public func value<Value: LosslessStringConvertible>(forKey key: Key) -> Value? {
        try? db.writeAndReturnError { db -> Value? in
            try value(forKey: key, db: db)
        }
    }
    
    public func set(_ value: LosslessStringConvertible, forKey key: Key) {
        try! db.writeAndReturnError { db in
            try set(value, forKey: key, db: db)
        }
    }
    
    public func set(_ value: LosslessStringConvertible, forKey key: Key, db: GRDB.Database) throws {
        let property = Property(key: key.rawValue,
                                value: value.description,
                                updatedAt: Date().toUTCString())
        try property.save(db)
    }
    
    public func removeValue(forKey key: Key) {
        try! db.writeAndReturnError { db in
            try removeValue(forKey: key, db: db)
        }
    }
    
    public func updateValue<Value: LosslessStringConvertible>(forKey key: Key, type: Value.Type, execute update: (Value?) -> Value?) {
        try! db.writeAndReturnError { db in
            let current: Value? = try value(forKey: key, db: db)
            if let new = update(current) {
                try set(new, forKey: key, db: db)
            } else {
                try removeValue(forKey: key, db: db)
            }
        }
    }
    
}

extension PropertiesDAO {
    
    private func value<Value: LosslessStringConvertible>(forKey key: Key, db: GRDB.Database) throws -> Value? {
        let string = try String.fetchOne(db,
                                         sql: "SELECT value FROM properties WHERE key=?",
                                         arguments: [key.rawValue],
                                         adapter: nil)
        if let string = string {
            return Value(string)
        } else {
            return nil
        }
    }
    
    private func removeValue(forKey key: Key, db: GRDB.Database) throws {
        try Property
            .filter(Property.column(of: .key) == key.rawValue)
            .deleteAll(db)
    }
    
}
