import GRDB

public final class SignalDatabase: Database {
    
    public static var current: SignalDatabase! = try! SignalDatabase(url: AppGroupContainer.signalDatabaseUrl)
    
    public override class var config: Configuration {
        var config = super.config
        config.label = "Signal"
        return config
    }
    
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("create_table") { db in
            try db.execute(sql: "CREATE TABLE identities(id INTEGER PRIMARY KEY AUTOINCREMENT, address TEXT, registrationId INTEGER, publicKey BLOB, privateKey BLOB, nextPreKeyId INTEGER, timestamp REAL)")
            try db.execute(sql: "CREATE TABLE prekeys(id INTEGER PRIMARY KEY AUTOINCREMENT, preKeyId INTEGER, record BLOB)")
            try db.execute(sql: "CREATE TABLE ratchet_sender_keys(groupId TEXT, senderId TEXT, status TEXT, CONSTRAINT _multi_primary PRIMARY KEY(groupId, senderId))")
            try db.execute(sql: "CREATE TABLE sender_keys(groupId TEXT, senderId TEXT, record BLOB, CONSTRAINT _multi_primary PRIMARY KEY(groupId, senderId))")
            try db.execute(sql: "CREATE TABLE sessions(id INTEGER PRIMARY KEY AUTOINCREMENT, address TEXT, device INTEGER, record BLOB, timestamp REAL)")
            try db.execute(sql: "CREATE TABLE signed_prekeys(id INTEGER PRIMARY KEY AUTOINCREMENT, preKeyId INTEGER, record BLOB, timestamp REAL)")
            
            try db.execute(sql: "CREATE UNIQUE INDEX identities_index_id ON identities(address)")
            try db.execute(sql: "CREATE UNIQUE INDEX prekeys_index_id ON prekeys(preKeyId)")
            try db.execute(sql: "CREATE UNIQUE INDEX sessions_multi_index ON sessions(address, device)")
            try db.execute(sql: "CREATE UNIQUE INDEX signed_prekeys_index_id ON signed_prekeys(preKeyId)")
        }
        
        return migrator
    }
    
    public static func rebuildCurrent() {
        current = try! SignalDatabase(url: AppGroupContainer.signalDatabaseUrl)
        current.migrate()
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
