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
                    `updated_at`    TEXT NOT NULL,
                    PRIMARY KEY(wallet_id)
                )
                """,
                """
                CREATE TABLE IF NOT EXISTS `addresses` (
                    `address_id`    TEXT NOT NULL,
                    `wallet_id`     TEXT NOT NULL,
                    `path`          TEXT,
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
                    `chain_id`  TEXT NOT NULL,
                    `name`      TEXT NOT NULL,
                    `symbol`    TEXT NOT NULL,
                    `icon_url`  TEXT NOT NULL,
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
                CREATE TABLE IF NOT EXISTS properties (
                    key         TEXT NOT NULL, 
                    value       TEXT NOT NULL, 
                    updated_at  TEXT NOT NULL, 
                    PRIMARY KEY(key)
                )
                """,
                """
                CREATE TABLE IF NOT EXISTS raw_transactions (
                    `hash`          TEXT NOT NULL,
                    `chain_id`      TEXT NOT NULL,
                    `account`       TEXT NOT NULL,
                    `nonce`         TEXT NOT NULL,
                    `raw`           TEXT NOT NULL,
                    `state`         TEXT NOT NULL,
                    `created_at`    TEXT NOT NULL,
                    `updated_at`    TEXT NOT NULL,
                    PRIMARY KEY(`hash`)
                )
                """,
            ]
            for sql in sqls {
                try db.execute(sql: sql)
            }
        }
        
        migrator.registerMigration("transactions") { db in
            let sqls = [
                "DROP TABLE IF EXISTS transactions",
                "DELETE FROM properties",
                """
                CREATE TABLE IF NOT EXISTS `transactions` (
                    `transaction_hash`  TEXT NOT NULL,
                    `chain_id`          TEXT NOT NULL,
                    `address`           TEXT NOT NULL,
                    `transaction_type`  TEXT NOT NULL,
                    `status`            TEXT NOT NULL,
                    `block_number`      INTEGER NOT NULL,
                    `fee`               TEXT NOT NULL,
                    `senders`           TEXT,
                    `receivers`         TEXT,
                    `approvals`         TEXT,
                    `send_asset_id`     TEXT,
                    `receive_asset_id`  TEXT,
                    `transaction_at`    TEXT NOT NULL,
                    `created_at`        TEXT NOT NULL,
                    `updated_at`        TEXT NOT NULL,
                    PRIMARY KEY(`transaction_hash`, `chain_id`, `address`)
                )
                """,
                "CREATE INDEX IF NOT EXISTS `index_transactions_address_transaction_at` ON `transactions` (`address`, `transaction_at`)",
            ]
            for sql in sqls {
                try db.execute(sql: sql)
            }
        }
        
        migrator.registerMigration("reputations") { db in
            var sqls: [String] = []
            
            let tokenInfos = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(tokens)")
            let tokenColumnNames = tokenInfos.map(\.name)
            if !tokenColumnNames.contains("level") {
                sqls.append("ALTER TABLE tokens ADD COLUMN level INTEGER NOT NULL DEFAULT \(Web3Reputation.Level.verified.rawValue)")
            }
            
            let transactionInfos = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(transactions)")
            let transactionColumnNames = transactionInfos.map(\.name)
            if !transactionColumnNames.contains("level") {
                sqls.append("ALTER TABLE transactions ADD COLUMN level INTEGER NOT NULL DEFAULT \(Web3Reputation.Level.unknown.rawValue)")
            }
            
            sqls.append(contentsOf: [
                "DELETE FROM properties",
                "DROP INDEX IF EXISTS `index_transactions_transaction_type_send_asset_id_receive_asset_id_transaction_at`",
                "CREATE INDEX IF NOT EXISTS `index_transactions_transaction_type_send_asset_id_receive_asset_id_transaction_at_level` ON `transactions` (`transaction_type`, `send_asset_id`, `receive_asset_id`, `transaction_at`, `level`)",
            ])
            
            for sql in sqls {
                try db.execute(sql: sql)
            }
        }
        
        migrator.registerMigration("reputations_2") { db in
            let sqls: [String] = [
                "DELETE FROM properties",
                "DELETE FROM tokens_extra",
            ]
            for sql in sqls {
                try db.execute(sql: sql)
            }
        }
        
        migrator.registerMigration("import_wallet") { db in
            let addressInfos = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(addresses)")
            let addressColumnNames = addressInfos.map(\.name)
            if !addressColumnNames.contains("path") {
                try db.execute(sql: "ALTER TABLE addresses ADD COLUMN path TEXT")
            }
        }
        
        migrator.registerMigration("swap_orders") { db in
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS `orders` (
                `order_id` TEXT NOT NULL,
                `wallet_id` TEXT NOT NULL,
                `user_id` TEXT NOT NULL,
                `pay_asset_id` TEXT NOT NULL,
                `receive_asset_id` TEXT NOT NULL,
                `pay_amount` TEXT NOT NULL,
                `receive_amount` TEXT,
                `pay_trace_id` TEXT,
                `receive_trace_id` TEXT,
                `state` TEXT NOT NULL,
                `created_at` TEXT NOT NULL,
                `order_type` TEXT NOT NULL,
                `pending_amount` TEXT,
                `filled_receive_amount` TEXT,
                `expected_receive_amount` TEXT,
                `expired_at` TEXT,
                PRIMARY KEY(`order_id`)
            )
            """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS `index_orders_state_created_at` ON `orders` (`state`, `created_at`)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS `index_orders_order_type_created_at` ON `orders` (`order_type`, `created_at`)")
        }
        
        migrator.registerMigration("safe_wallets") { db in
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS safe_wallets (
                wallet_id       TEXT NOT NULL,
                name            TEXT NOT NULL,
                created_at      TEXT NOT NULL,
                updated_at      TEXT NOT NULL,
                role            TEXT NOT NULL,
                chain_id        TEXT NOT NULL,
                address         TEXT NOT NULL,
                uri             TEXT NOT NULL,
                PRIMARY KEY(wallet_id)
            )
            """)
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
        Logger.database.error(category: "Web3Database", message: "Table lost with error: \(error)")
        AppGroupUserDefaults.User.needsRebuildDatabase = true
    }
    
    private func migrate() {
        try! migrator.migrate(pool)
    }
    
}
