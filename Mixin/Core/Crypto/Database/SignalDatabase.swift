import Foundation
import WCDBSwift
import Bugsnag

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
            Bugsnag.notifyError(error)
        }
    }

    func logout(onClosed: @escaping () -> Void) {
        database.close(onClosed: {
            do {
                try database.removeFiles()
            } catch {
                UIApplication.trackError("SignalDatabase", action: "logout remove database failded")
            }
            DispatchQueue.main.async {
                CryptoUserDefault.shared.reset()
                SignalDatabase.shared.configure(reset: true)
                onClosed()
            }
        })
    }

}
