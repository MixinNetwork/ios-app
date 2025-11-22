import Foundation
import GRDB

public final class PropertiesDAO: UserDatabaseDAO {
    
    public static let propertyDidUpdateNotification = Notification.Name("one.mixin.services.PropertiesDAO.Update")
    
    public enum Key: String {
        case iterator
        case snapshotOffset     = "snapshot_offset"
        case globalMarket       = "global_market"
        case mixinSwapRecentSendIDs     = "mixin_swap_recent_send"
        case mixinSwapRecentReceiveIDs  = "mixin_swap_recent_receive"
        case transferRecentAssetIDs     = "transfer_recent_assets"
    }
    
    public enum Change {
        case removed
        case saved(LosslessStringConvertible)
    }
    
    public static let shared = PropertiesDAO()
    
    // Maybe not the newest
    public func unsafeValue<Value: LosslessStringConvertible>(forKey key: Key) -> Value? {
        try? db.read { db -> Value? in
            try value(forKey: key, db: db)
        }
    }
    
    public func value<Value: LosslessStringConvertible>(forKey key: Key) -> Value? {
        assert(!Thread.isMainThread) // Prevent deadlock
        return try? db.writeAndReturnError { db -> Value? in
            try value(forKey: key, db: db)
        }
    }
    
    public func jsonObject<Value: Decodable>(forKey key: Key, type: Value.Type) -> Value? {
        assert(!Thread.isMainThread) // Prevent deadlock
        return try? db.writeAndReturnError { db -> Value? in
            let string: String? = try value(forKey: key, db: db)
            if let data = string?.data(using: .utf8)  {
                return try JSONDecoder.default.decode(type, from: data)
            } else {
                return nil
            }
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
        try db.afterNextTransaction { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.propertyDidUpdateNotification,
                                                object: self,
                                                userInfo: [key: Change.saved(value)])
            }
        }
    }
    
    public func set<Value: Encodable>(jsonObject: Value, forKey key: Key) {
        guard let data = try? JSONEncoder.default.encode(jsonObject) else {
            return
        }
        guard let string = String(data: data, encoding: .utf8) else {
            return
        }
        try? db.writeAndReturnError { db in
            try set(string, forKey: key, db: db)
        }
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
                                         arguments: [key.rawValue])
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
        try db.afterNextTransaction { _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.propertyDidUpdateNotification,
                                                object: self,
                                                userInfo: [key: Change.removed])
            }
        }
    }
    
}

// Raw access without notifications
extension PropertiesDAO {
    
    public func unsafeValue<Value: LosslessStringConvertible>(forKey key: String) -> Value? {
        try? db.read { db -> Value? in
            let string = try String.fetchOne(
                db,
                sql: "SELECT value FROM properties WHERE key=?",
                arguments: [key]
            )
            if let string = string {
                return Value(string)
            } else {
                return nil
            }
        }
    }
    
    public func setWithoutNotification(_ value: LosslessStringConvertible, forKey key: String) {
        try! db.writeAndReturnError { db in
            let property = Property(
                key: key,
                value: value.description,
                updatedAt: Date().toUTCString()
            )
            try property.save(db)
        }
    }
    
    public func removeValueWithoutNotification(forKey key: String) {
        try! db.writeAndReturnError { db in
            try Property
                .filter(Property.column(of: .key) == key)
                .deleteAll(db)
        }
    }
    
}
