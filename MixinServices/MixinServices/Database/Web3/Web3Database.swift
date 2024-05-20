import GRDB

public class Web3Database: Database {
    
    public private(set) static var current: Web3Database = makeDatabaseWithDefaultLocation()
    
    public override class var config: Configuration {
        var config = super.config
        config.label = "Web3"
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
            let sql = """
            CREATE TABLE IF NOT EXISTS `transactions` (
                `transaction_hash` TEXT NOT NULL,
                `chain_id` TEXT NOT NULL,
                `address` TEXT NOT NULL,
                `raw_transaction` TEXT NOT NULL,
                `nonce` INTEGER NOT NULL,
                `created_at` TEXT NOT NULL,
                PRIMARY KEY(`transaction_hash`, `chain_id`)
            )
            """
            try db.execute(sql: sql)
        }
        
        return migrator
    }
    
    public static func reloadCurrent() {
        current = makeDatabaseWithDefaultLocation()
        current.migrate()
    }
    
    private static func makeDatabaseWithDefaultLocation() -> Web3Database {
        let db = try! Web3Database(url: AppGroupContainer.web3DatabaseURL)
        if AppGroupUserDefaults.User.needsRebuildDatabase {
            try? db.pool.barrierWriteWithoutTransaction { (db) -> Void in
                try db.execute(sql: "DROP TABLE IF EXISTS grdb_migrations")
            }
        }
        return db
    }
    
    public override func tableDidLose(with error: Error?, fileSize: Int64?, fileCreationDate: Date?) {
        let error: MixinServicesError = .databaseCorrupted(database: "web3",
                                                           isAppExtension: isAppExtension,
                                                           error: error,
                                                           fileSize: fileSize,
                                                           fileCreationDate: fileCreationDate)
        reporter.report(error: error)
        Logger.database.error(category: "Web3Database", message: "Table lost with error: \(error)")
        AppGroupUserDefaults.User.needsRebuildDatabase = true
    }
    
    private func migrate() {
        try! migrator.migrate(pool)
    }
    
}
