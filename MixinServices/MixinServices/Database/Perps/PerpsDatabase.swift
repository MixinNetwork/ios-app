import GRDB

public final class PerpsDatabase: Database {
    
    public private(set) static var current: PerpsDatabase! = makeDatabaseWithDefaultLocation()
    
    public override class var config: Configuration {
        var config = super.config
        config.label = "Perps"
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
                CREATE TABLE IF NOT EXISTS `markets` (
                    `market_id` TEXT NOT NULL,
                    `id` INTEGER NOT NULL,
                    `market` TEXT NOT NULL,
                    `symbol` TEXT NOT NULL,
                    `display_symbol` TEXT NOT NULL,
                    `token_symbol` TEXT NOT NULL,
                    `fee_mode` INTEGER NOT NULL,
                    `mark_method` TEXT NOT NULL,
                    `mark_price` TEXT NOT NULL,
                    `maker_fee` TEXT NOT NULL,
                    `taker_fee` TEXT NOT NULL,
                    `base_interest` TEXT NOT NULL,
                    `quote_interest` TEXT NOT NULL,
                    `funding_rate` TEXT NOT NULL,
                    `predicted_funding_rate` TEXT NOT NULL,
                    `next_funding_time` INTEGER NOT NULL,
                    `prev_funding_time` INTEGER NOT NULL,
                    `quantity_scale` INTEGER NOT NULL,
                    `price_scale` INTEGER NOT NULL,
                    `min_order_size` TEXT NOT NULL,
                    `max_order_size` TEXT NOT NULL,
                    `min_order_value` TEXT NOT NULL,
                    `max_order_value` TEXT NOT NULL,
                    `quantity_increment` TEXT NOT NULL,
                    `price_increment` TEXT NOT NULL,
                    `profit_sharing` TEXT NOT NULL,
                    `mini` INTEGER NOT NULL,
                    `time` INTEGER NOT NULL,
                    `leverage` INTEGER NOT NULL,
                    `icon_url` TEXT NOT NULL,
                    `last` TEXT NOT NULL,
                    `volume` TEXT NOT NULL,
                    `amount` TEXT NOT NULL,
                    `high` TEXT NOT NULL,
                    `low` TEXT NOT NULL,
                    `open` TEXT NOT NULL,
                    `change` TEXT NOT NULL,
                    `bid_price` TEXT NOT NULL,
                    `ask_price` TEXT NOT NULL,
                    `trade_count` INTEGER NOT NULL,
                    `first_trade_id` TEXT NOT NULL,
                    `created_at` TEXT NOT NULL,
                    `updated_at` TEXT NOT NULL,
                    PRIMARY KEY(market_id)
                )
                """,
                """
                CREATE TABLE IF NOT EXISTS `positions` (
                    `position_id` TEXT NOT NULL,
                    `product_id` TEXT NOT NULL,
                    `side` TEXT NOT NULL,
                    `quantity` TEXT NOT NULL,
                    `entry_price` TEXT NOT NULL,
                    `margin` TEXT NOT NULL,
                    `leverage` INTEGER NOT NULL,
                    `state` TEXT NOT NULL,
                    `mark_price` TEXT NOT NULL,
                    `unrealized_pnl` TEXT NOT NULL,
                    `roe` TEXT NOT NULL,
                    `settle_asset_id` TEXT NOT NULL,
                    `bot_id` TEXT NOT NULL,
                    `wallet_id` TEXT NOT NULL,
                    `created_at` TEXT NOT NULL,
                    `updated_at` TEXT NOT NULL,
                    PRIMARY KEY(`position_id`)
                )
                """,
                """
                CREATE TABLE IF NOT EXISTS `position_histories` (
                    `history_id` TEXT NOT NULL,
                    `position_id` TEXT NOT NULL,
                    `product_id` TEXT NOT NULL,
                    `side` TEXT NOT NULL,
                    `quantity` TEXT NOT NULL,
                    `entry_price` TEXT NOT NULL,
                    `close_price` TEXT NOT NULL,
                    `realized_pnl` TEXT NOT NULL,
                    `leverage` INTEGER NOT NULL,
                    `margin_method` TEXT NOT NULL,
                    `open_at` TEXT NOT NULL,
                    `closed_at` TEXT NOT NULL,
                    PRIMARY KEY(`history_id`)
                )
                """,
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
    
    private static func makeDatabaseWithDefaultLocation() -> PerpsDatabase {
        let db = try! PerpsDatabase(url: AppGroupContainer.perpsDatabaseUrl)
        if AppGroupUserDefaults.User.needsRebuildDatabase {
            try? db.pool.barrierWriteWithoutTransaction { (db) -> Void in
                try db.execute(sql: "DROP TABLE IF EXISTS grdb_migrations")
            }
        }
        return db
    }
    
    public override func tableDidLose(with error: Error?, fileSize: Int64?, fileCreationDate: Date?) {
        let error: MixinServicesError = .databaseCorrupted(
            database: "perps",
            isAppExtension: isAppExtension,
            error: error,
            fileSize: fileSize,
            fileCreationDate: fileCreationDate
        )
        reporter.report(error: error)
        Logger.database.error(category: "PerpsDatabase", message: "Table lost with error: \(error)")
        AppGroupUserDefaults.User.needsRebuildDatabase = true
    }
    
    private func migrate() {
        try! migrator.migrate(pool)
    }
    
}
