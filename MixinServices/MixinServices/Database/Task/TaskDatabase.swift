import GRDB

public class TaskDatabase: Database {
    
    public private(set) static var current: TaskDatabase! = makeDatabaseWithDefaultLocation()
    
    public override class var config: Configuration {
        var config = super.config
        config.label = "Task"
        return config
    }
    
    public override var needsMigration: Bool {
        try! read { (db) -> Bool in
            let migrationsCompleted = try migrator.hasCompletedMigrations(db)
            return !migrationsCompleted
        }
    }
    
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("create_table") { db in
            let messageBlaze = ColumnMigratableTableDefinition<MessageBlaze>(constraints: nil, columns: [
                .init(key: .messageId, constraints: "TEXT PRIMARY KEY"),
                .init(key: .message, constraints: "BLOB NOT NULL"),
                .init(key: .createdAt, constraints: "TEXT NOT NULL"),
            ])
            try self.migrateTable(with: messageBlaze, into: db)
            
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS messages_blaze_index ON messages_blaze(created_at)")
        }
        
        migrator.registerMigration("wcdb") { (db) in
            try db.execute(sql: "DROP INDEX IF EXISTS messages_blaze_conversation_indexs")
        }
        
        return migrator
    }
    
    public static func reloadCurrent() {
        current = makeDatabaseWithDefaultLocation()
        current.migrate()
    }
    
    private static func makeDatabaseWithDefaultLocation() -> TaskDatabase {
        let db = try! TaskDatabase(url: AppGroupContainer.taskDatabaseUrl)
        if AppGroupUserDefaults.User.needsRebuildDatabase {
            try? db.pool.barrierWriteWithoutTransaction { (db) -> Void in
                try db.execute(sql: "DROP TABLE IF EXISTS grdb_migrations")
            }
        }
        return db
    }
    
    public override func tableDidLose() {
        AppGroupUserDefaults.User.needsRebuildDatabase = true
    }
    
    private func migrate() {
        try! migrator.migrate(pool)
    }
    
}
