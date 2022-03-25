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
                .init(key: .conversationId, constraints: "TEXT NOT NULL"),
                .init(key: .createdAt, constraints: "TEXT NOT NULL"),
            ])
            try self.migrateTable(with: messageBlaze, into: db)
            
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS messages_blaze_index ON messages_blaze(created_at)")
        }
        
        migrator.registerMigration("wcdb") { (db) in
            try db.execute(sql: "DROP INDEX IF EXISTS messages_blaze_conversation_indexs")
        }
        
        migrator.registerMigration("batch_process_messages") { (db) in
            let infos = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(messages_blaze)")
            let columnNames = infos.map(\.name)
            if !columnNames.contains("conversation_id") {
                try db.execute(sql: "ALTER TABLE messages_blaze ADD COLUMN conversation_id TEXT NOT NULL DEFAULT ''")
            }
            
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS index_conversation_messages ON messages_blaze(conversation_id, created_at)")
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
    
    public override func tableDidLose(with error: Error?, fileSize: Int64?, fileCreationDate: Date?) {
        let error: MixinServicesError = .databaseCorrupted(database: "task",
                                                           isAppExtension: isAppExtension,
                                                           error: error,
                                                           fileSize: fileSize,
                                                           fileCreationDate: fileCreationDate)
        reporter.report(error: error)
        Logger.database.error(category: "TaskDatabase", message: "Table lost with error: \(error)")
        AppGroupUserDefaults.User.needsRebuildDatabase = true
    }
    
    private func migrate() {
        try! migrator.migrate(pool)
    }
    
}
