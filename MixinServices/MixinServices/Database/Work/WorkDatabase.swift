import GRDB

public final class WorkDatabase: Database {
    
    public private(set) static var current: WorkDatabase! = try! WorkDatabase(url: AppGroupContainer.workDatabaseURL)
    
    public override class var config: Configuration {
        var config = super.config
        config.label = "Work"
        return config
    }
    
    public override var needsMigration: Bool {
        try! pool.read({ (db) -> Bool in
            let migrationsCompleted = try migrator.hasCompletedMigrations(db)
            return !migrationsCompleted
        })
    }
    
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("create_table") { db in
            try db.create(table: "works") { td in
                td.column("id", .text).primaryKey().notNull()
                td.column("type", .text).notNull()
                td.column("context", .blob)
                td.column("priority", .integer).notNull()
            }
        }
        
        return migrator
    }
    
    public static func reloadCurrent() {
        current = try! WorkDatabase(url: AppGroupContainer.workDatabaseURL)
        current.migrate()
    }
    
    private func migrate() {
        try! migrator.migrate(pool)
    }
    
}
