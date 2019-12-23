import WCDBSwift

public final class TaskDatabase: BaseDatabase {
    
    private static let databaseVersion: Int = 1
    
    public static let shared = TaskDatabase()
    
    private lazy var _database = Database(withPath: AppGroupContainer.taskDatabaseUrl.path)
    
    override var database: Database! {
        get { return _database }
        set { }
    }
    
    public func initDatabase() {
        _database = Database(withPath: AppGroupContainer.taskDatabaseUrl.path)
        do {
            try database.run(transaction: {
                try database.create(of: MessageBlaze.self)
                try database.setDatabaseVersion(version: TaskDatabase.databaseVersion)
            })
        } catch {
            Reporter.report(error: error)
        }
    }
    
}
