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
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS identities(id INTEGER PRIMARY KEY AUTOINCREMENT, address TEXT, registrationId INTEGER, publicKey BLOB, privateKey BLOB, nextPreKeyId INTEGER, timestamp REAL)")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS prekeys(id INTEGER PRIMARY KEY AUTOINCREMENT, preKeyId INTEGER, record BLOB)")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS ratchet_sender_keys(groupId TEXT, senderId TEXT, status TEXT, PRIMARY KEY(groupId, senderId))")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS sender_keys(groupId TEXT, senderId TEXT, record BLOB, PRIMARY KEY(groupId, senderId))")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS sessions(id INTEGER PRIMARY KEY AUTOINCREMENT, address TEXT, device INTEGER, record BLOB, timestamp REAL)")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS signed_prekeys(id INTEGER PRIMARY KEY AUTOINCREMENT, preKeyId INTEGER, record BLOB, timestamp REAL)")
            
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
