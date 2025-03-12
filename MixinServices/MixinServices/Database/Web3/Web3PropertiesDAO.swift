import Foundation
import GRDB

public final class Web3PropertiesDAO: Web3DAO {
    
    public static let shared = Web3PropertiesDAO()
    
    public func transactionOffset(address: String) -> String? {
        try? db.read { db -> String? in
            try value(forKey: address, db: db)
        }
    }
    
    public func set(
        transactionOffset: String,
        forAddress address: String,
        db: GRDB.Database
    ) throws {
        let property = Property(
            key: address,
            value: transactionOffset,
            updatedAt: Date().toUTCString()
        )
        try property.save(db)
    }
    
}

extension Web3PropertiesDAO {
    
    private func value<Value: LosslessStringConvertible>(
        forKey key: String,
        db: GRDB.Database
    ) throws -> Value? {
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
    
    private func removeValue(forKey key: String, db: GRDB.Database) throws {
        try Property
            .filter(Property.column(of: .key) == key)
            .deleteAll(db)
    }
    
}
