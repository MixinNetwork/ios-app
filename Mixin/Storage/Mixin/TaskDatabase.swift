import WCDBSwift

class TaskDatabase: BaseDatabase {

    private static let databaseVersion: Int = 1

    static let shared = TaskDatabase()

    private lazy var _database = Database(withPath: MixinFile.taskDatabaseURL.path)
    override var database: Database! {
        get { return _database }
        set { }
    }

    func initDatabase() {
        _database = Database(withPath: MixinFile.taskDatabaseURL.path)
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
