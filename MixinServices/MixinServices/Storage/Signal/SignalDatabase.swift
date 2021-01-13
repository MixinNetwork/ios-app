import GRDB

public final class SignalDatabase: Database {
    
    public private(set) static var current: SignalDatabase! = makeDatabaseWithDefaultLocation()
    
    public override class var config: Configuration {
        var config = super.config
        config.label = "Signal"
        return config
    }
    
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("create_table") { db in
            let identities = TableDefinition<Identity>(constraints: nil, columns: [
                .init(key: .address, constraints: "TEXT"),
                .init(key: .registrationId, constraints: "INTEGER"),
                .init(key: .publicKey, constraints: "BLOB"),
                .init(key: .privateKey, constraints: "BLOB"),
                .init(key: .nextPreKeyId, constraints: "INTEGER"),
                .init(key: .timestamp, constraints: "REAL"),
            ])
            try self.migrateTable(with: identities, into: db)
            
            let prekeys = TableDefinition<PreKey>(constraints: nil, columns: [
                .init(key: .preKeyId, constraints: "INTEGER"),
                .init(key: .record, constraints: "BLOB"),
            ])
            try self.migrateTable(with: prekeys, into: db)
            
            let ratchetSenderKeys = TableDefinition<RatchetSenderKey>(constraints: "PRIMARY KEY(groupId, senderId)", columns: [
                .init(key: .groupId, constraints: "TEXT"),
                .init(key: .senderId, constraints: "TEXT"),
                .init(key: .status, constraints: "TEXT"),
            ])
            try self.migrateTable(with: ratchetSenderKeys, into: db)
            
            let senderKeys = TableDefinition<SenderKey>(constraints: "PRIMARY KEY(groupId, senderId)", columns: [
                .init(key: .groupId, constraints: "TEXT"),
                .init(key: .senderId, constraints: "TEXT"),
                .init(key: .record, constraints: "BLOB"),
            ])
            try self.migrateTable(with: senderKeys, into: db)
            
            let sessions = TableDefinition<Session>(constraints: nil, columns: [
                .init(key: .address, constraints: "TEXT"),
                .init(key: .device, constraints: "INTEGER"),
                .init(key: .record, constraints: "BLOB"),
                .init(key: .timestamp, constraints: "REAL"),
            ])
            try self.migrateTable(with: sessions, into: db)
            
            let signedPreKeys = TableDefinition<SignedPreKey>(constraints: nil, columns: [
                .init(key: .preKeyId, constraints: "INTEGER"),
                .init(key: .record, constraints: "BLOB"),
                .init(key: .timestamp, constraints: "REAL"),
            ])
            try self.migrateTable(with: signedPreKeys, into: db)
            
            try db.execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS identities_index_id ON identities(address)")
            try db.execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS prekeys_index_id ON prekeys(preKeyId)")
            try db.execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS sessions_multi_index ON sessions(address, device)")
            try db.execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS signed_prekeys_index_id ON signed_prekeys(preKeyId)")
        }
        
        return migrator
    }
    
    public static func reloadCurrent() {
        current = makeDatabaseWithDefaultLocation()
        current.migrate()
    }
    
    public static func closeCurrent() {
        current = nil
    }
    
    private static func makeDatabaseWithDefaultLocation() -> SignalDatabase {
        try! SignalDatabase(url: AppGroupContainer.signalDatabaseUrl)
    }
    
    public func erase() {
        do {
            try pool.erase()
        } catch {
            Logger.writeDatabase(error: error)
            reporter.report(error: error)
        }
    }
    
    private func migrate() {
        try! migrator.migrate(pool)
    }
    
}
