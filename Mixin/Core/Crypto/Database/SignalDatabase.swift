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

    func initDatabase() throws {
        database.setSynchronous(isFull: true)
        try database.run(transaction: {
            try database.create(of: Identity.self)
            try database.create(of: PreKey.self)
            try database.create(of: RatchetSenderKey.self)
            try database.create(of: SenderKey.self)
            try database.create(of: Session.self)
            try database.create(of: SignedPreKey.self)
            try database.setDatabaseVersion(version: SignalDatabase.databaseVersion)
        })
    }

    func logout() {
        do {
            try database.run(transaction: {
                try database.delete(fromTable: Identity.tableName)
                try database.delete(fromTable: PreKey.tableName)
                try database.delete(fromTable: RatchetSenderKey.tableName)
                try database.delete(fromTable: SenderKey.tableName)
                try database.delete(fromTable: Session.tableName)
                try database.delete(fromTable: SignedPreKey.tableName)
            })
        } catch let err as WCDBSwift.Error {
            UIApplication.traceWCDBError(err)
        } catch {
            UIApplication.traceError(error)
        }
        AppGroupUserDefaults.Crypto.clearAll()
    }

}
