import Foundation
import WCDBSwift

class SignalDatabase: BaseDatabase {

    private static let databaseVersion: Int = 2

    static let shared = SignalDatabase()

    private var _database = Database(withPath: MixinFile.signalDatabasePath)
    override var database: Database! {
        get { return _database }
        set { }
    }

    override func configure(reset: Bool = false) {
        if reset {
            self._database = Database(withPath: MixinFile.signalDatabasePath)
        }
        do {
            database.setSynchronous(isFull: true)
            try database.run(transaction: {
                try database.create(of: Identity.self)
                try database.create(of: PreKey.self)
                try database.create(of: RatchetSenderKey.self)
                try database.create(of: SenderKey.self)
                try database.create(of: Session.self)
                try database.create(of: SignedPreKey.self)

                if DatabaseUserDefault.shared.signalDatabaseVersion > 0 && DatabaseUserDefault.shared.signalDatabaseVersion < 2 {
                    try database.prepareUpdateSQL(sql: "DROP INDEX IF EXISTS sessions_index_id").execute()
                    try database.prepareUpdateSQL(sql: "UPDATE sessions SET address = substr(address, 1, 36), device = 1 WHERE length(address) = 38").execute()
                }
                DatabaseUserDefault.shared.signalDatabaseVersion = SignalDatabase.databaseVersion
            })
        } catch {
            UIApplication.traceError(error)
        }
    }

    func logout(onClosed: @escaping () -> Void) {
        database.close(onClosed: {
            do {
                try database.removeFiles()
            } catch {
                UIApplication.traceError(code: ReportErrorCode.databaseRemoveFailed, userInfo: ["database": "signal"])
            }
            DispatchQueue.main.async {
                CryptoUserDefault.shared.reset()
                SignalDatabase.shared.configure(reset: true)
                onClosed()
            }
        })
    }

}
