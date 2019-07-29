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
            CryptoUserDefault.shared.reset()
            SignalDatabase.shared.configure(reset: true)
            DispatchQueue.main.async {
                onClosed()
            }
        })
    }

}
