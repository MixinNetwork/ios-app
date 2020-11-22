import WCDBSwift

public final class TaskDatabase: BaseDatabase {
    
    private static let databaseVersion: Int = 2
    
    public static let shared = TaskDatabase()
    
    private lazy var _database = Database(path: AppGroupContainer.taskDatabaseUrl.path)
    
    override var database: Database! {
        get { return _database }
        set { }
    }
    
    public func initDatabase() {
        _database = Database(path: AppGroupContainer.taskDatabaseUrl.path)
        do {
            try database.run(transaction: {
                var currentVersion = try database.getDatabaseVersion()
                try self.createBefore(database: database, currentVersion: currentVersion)

                try database.create(of: MessageBlaze.self)
                try database.setDatabaseVersion(version: TaskDatabase.databaseVersion)
            })
        } catch {
            Logger.writeDatabase(error: error)
            reporter.report(error: error)
        }
    }

    private func createBefore(database: Database, currentVersion: Int) throws {
        guard currentVersion > 0 else {
            return
        }

        if currentVersion < 1 {
            try database.prepareUpdateSQL(sql: "DROP INDEX IF EXISTS messages_blaze_conversation_indexs").execute()
        }
    }
}
