import WCDBSwift

class JobDatabase: BaseDatabase {

    private static let databaseVersion: Int = 1

    static let shared = JobDatabase()

    private lazy var _database = Database(withPath: MixinFile.jobDatabaseURL.path)
    override var database: Database! {
        get { return _database }
        set { }
    }

    override func configure(reset: Bool = false) {
        if MixinFile.jobDatabaseURL.path != _database.path {
            _database.close()
            _database = Database(withPath: MixinFile.jobDatabaseURL.path)
        }
        do {
            database.setSynchronous(isFull: true)
            try database.run(transaction: {
                try database.create(of: MessageBlaze.self)
                try database.create(of: MessageHistory.self)

                try database.create(of: Job.self)
                try database.create(of: ResendMessage.self)
                DatabaseUserDefault.shared.jobDatabaseVersion = JobDatabase.databaseVersion
            })
        } catch {
            UIApplication.traceError(error)
        }
    }

    func logout() {
        database.close()
    }

    static func getIntance() -> BaseDatabase {
        return JobDatabase.shared
    }
}
