import GRDB

public final class Web3Database: Database {
    
    public private(set) static var current: Web3Database! = makeDatabaseWithDefaultLocation()
    
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
            let sqls = [
                """
                CREATE TABLE IF NOT EXISTS `wallets` (
                    `wallet_id`     TEXT NOT NULL,
                    `category`      TEXT NOT NULL,
                    `name`          TEXT NOT NULL,
                    `created_at`    TEXT NOT NULL,
                    PRIMARY KEY(wallet_id)
                )
                """,
                """
                CREATE TABLE IF NOT EXISTS `addresses` (
                    `address_id`    TEXT NOT NULL,
                    `wallet_id`     TEXT NOT NULL,
                    `chain_id`      TEXT NOT NULL,
                    `destination`   TEXT NOT NULL,
                    `created_at`    TEXT NOT NULL,
                    PRIMARY KEY(address_id)
                )
                """,
                """
                CREATE TABLE IF NOT EXISTS `tokens` (
                    `wallet_id`         TEXT NOT NULL,
                    `asset_id`          TEXT NOT NULL,
                    `chain_id`          TEXT NOT NULL,
                    `name`              TEXT NOT NULL,
                    `asset_key`         TEXT NOT NULL,
                    `symbol`            TEXT NOT NULL,
                    `icon_url`          TEXT NOT NULL,
                    `precision`         INTEGER NOT NULL,
                    `kernel_asset_id`   TEXT NOT NULL,
                    `amount`            TEXT NOT NULL,
                    `price_usd`         TEXT NOT NULL,
                    `change_usd`        TEXT NOT NULL,
                    PRIMARY KEY(`wallet_id`, `asset_id`)
                )
                """,
                """
                CREATE TABLE IF NOT EXISTS `chains` (
                    `chain_id` TEXT NOT NULL,
                    `name` TEXT NOT NULL,
                    `symbol` TEXT NOT NULL,
                    `icon_url` TEXT NOT NULL,
                    `threshold` INTEGER NOT NULL,
                    `withdrawal_memo_possibility` TEXT NOT NULL DEFAULT 'possible',
                    PRIMARY KEY(`chain_id`)
                )
                """,
                """
                CREATE TABLE IF NOT EXISTS `tokens_extra` (
                  `wallet_id`   TEXT NOT NULL,
                  `asset_id`    TEXT NOT NULL,
                  `hidden`      INTEGER,
                  PRIMARY KEY(`wallet_id`, `asset_id`)
                )
                """,
                """
                CREATE TABLE IF NOT EXISTS `transactions` (
                    `transaction_id`    TEXT NOT NULL,
                    `transaction_type`  TEXT NOT NULL,
                    `transaction_hash`  TEXT NOT NULL,
                    `output_index`      INTEGER NOT NULL,
                    `block_number`      INTEGER NOT NULL,
                    `sender`            TEXT NOT NULL,
                    `receiver`          TEXT NOT NULL,
                    `output_hash`       TEXT NOT NULL,
                    `chain_id`          TEXT NOT NULL,
                    `asset_id`          TEXT NOT NULL,
                    `amount`            TEXT NOT NULL,
                    `created_at`        TEXT NOT NULL,
                    `updated_at`        TEXT NOT NULL,
                    `transaction_at`    TEXT NOT NULL,
                    `status`            TEXT NOT NULL,
                    PRIMARY KEY(`transaction_id`)
                )
                """,
                """
                CREATE TABLE IF NOT EXISTS properties (
                    key TEXT NOT NULL, 
                    value TEXT NOT NULL, 
                    updated_at TEXT NOT NULL, 
                    PRIMARY KEY(key)
                )
                """,
                "CREATE INDEX IF NOT EXISTS `index_transactions_transaction_at` ON `transactions` (`transaction_at`)",
                "CREATE INDEX IF NOT EXISTS `index_transactions_transaction_type_asset_id` ON `transactions` (`transaction_type`, `asset_id`)",
            ]
            for sql in sqls {
                try db.execute(sql: sql)
            }
        }
        
        return migrator
    }
    
    public static func reloadCurrent() {
        current = makeDatabaseWithDefaultLocation()
        current.migrate()
    }
    
    private static func makeDatabaseWithDefaultLocation() -> Web3Database {
        let db = try! Web3Database(url: AppGroupContainer.web3DatabaseUrl)
        if AppGroupUserDefaults.User.needsRebuildDatabase {
            try? db.pool.barrierWriteWithoutTransaction { (db) -> Void in
                try db.execute(sql: "DROP TABLE IF EXISTS grdb_migrations")
            }
        }
        return db
    }
    
    public override func tableDidLose(with error: Error?, fileSize: Int64?, fileCreationDate: Date?) {
        let error: MixinServicesError = .databaseCorrupted(
            database: "web3",
            isAppExtension: isAppExtension,
            error: error,
            fileSize: fileSize,
            fileCreationDate: fileCreationDate
        )
        reporter.report(error: error)
        Logger.database.error(category: "TaskDatabase", message: "Table lost with error: \(error)")
        AppGroupUserDefaults.User.needsRebuildDatabase = true
    }
    
    private func migrate() {
        try! migrator.migrate(pool)
    }
    
}
