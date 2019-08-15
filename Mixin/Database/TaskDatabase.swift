import WCDBSwift

class TaskDatabase: BaseDatabase {

    private static let databaseVersion: Int = 1

    static let shared = TaskDatabase()

    private lazy var _database = Database(withPath: MixinFile.taskDatabaseURL.path)
    override var database: Database! {
        get { return _database }
        set { }
    }

    func initDatabase() throws {
        database.setSynchronous(isFull: true)
        try database.run(transaction: {
            try database.create(of: MessageBlaze.self)
            DatabaseUserDefault.shared.taskDatabaseVersion = TaskDatabase.databaseVersion
        })
    }
}
