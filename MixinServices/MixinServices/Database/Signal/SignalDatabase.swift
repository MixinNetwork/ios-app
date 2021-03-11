import GRDB

public final class SignalDatabase: Database {
    
    public private(set) static var current: SignalDatabase! = makeDatabaseWithDefaultLocation()
    
    public override class var config: Configuration {
        var config = super.config
        config.label = "Signal"
        return config
    }
    
    internal lazy var tableMigrations: [ColumnMigratable] = [
        ColumnMigratableTableDefinition<Identity>(constraints: nil, columns: [
            .init(key: .address, constraints: "TEXT NOT NULL"),
            .init(key: .registrationId, constraints: "INTEGER"),
            .init(key: .publicKey, constraints: "BLOB NOT NULL"),
            .init(key: .privateKey, constraints: "BLOB"),
            .init(key: .nextPreKeyId, constraints: "INTEGER"),
            .init(key: .timestamp, constraints: "REAL NOT NULL"),
        ]),
        ColumnMigratableTableDefinition<PreKey>(constraints: nil, columns: [
            .init(key: .preKeyId, constraints: "INTEGER NOT NULL"),
            .init(key: .record, constraints: "BLOB NOT NULL"),
        ]),
        ColumnMigratableTableDefinition<RatchetSenderKey>(constraints: "PRIMARY KEY(groupId, senderId)", columns: [
            .init(key: .groupId, constraints: "TEXT NOT NULL"),
            .init(key: .senderId, constraints: "TEXT NOT NULL"),
            .init(key: .status, constraints: "TEXT NOT NULL"),
        ]),
        ColumnMigratableTableDefinition<SenderKey>(constraints: "PRIMARY KEY(groupId, senderId)", columns: [
            .init(key: .groupId, constraints: "TEXT NOT NULL"),
            .init(key: .senderId, constraints: "TEXT NOT NULL"),
            .init(key: .record, constraints: "BLOB NOT NULL"),
        ]),
        ColumnMigratableTableDefinition<Session>(constraints: nil, columns: [
            .init(key: .address, constraints: "TEXT NOT NULL"),
            .init(key: .device, constraints: "INTEGER NOT NULL"),
            .init(key: .record, constraints: "BLOB NOT NULL"),
            .init(key: .timestamp, constraints: "REAL NOT NULL"),
        ]),
        ColumnMigratableTableDefinition<SignedPreKey>(constraints: nil, columns: [
            .init(key: .preKeyId, constraints: "INTEGER NOT NULL"),
            .init(key: .record, constraints: "BLOB NOT NULL"),
            .init(key: .timestamp, constraints: "REAL NOT NULL"),
        ])
    ]
    
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("create_table") { db in
            for table in self.tableMigrations {
                try self.migrateTable(with: table, into: db)
            }
            
            try db.execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS identities_index_id ON identities(address)")
            try db.execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS prekeys_index_id ON prekeys(preKeyId)")
            try db.execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS sessions_multi_index ON sessions(address, device)")
            try db.execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS signed_prekeys_index_id ON signed_prekeys(preKeyId)")
        }
        
        return migrator
    }
    
    public static func reloadCurrent(with db: SignalDatabase? = nil) {
        current = db ?? makeDatabaseWithDefaultLocation()
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
