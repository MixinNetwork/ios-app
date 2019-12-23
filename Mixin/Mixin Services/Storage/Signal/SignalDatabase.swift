import Foundation
import WCDBSwift

public class SignalDatabase: BaseDatabase {
    
    private static let databaseVersion: Int = 2
    
    public static let shared = SignalDatabase()
    
    private var _database = Database(withPath: AppGroupContainer.signalDatabaseUrl.path)
    
    override var database: Database! {
        get { return _database }
        set { }
    }
    
    public func initDatabase() throws {
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
    
    public func logout() {
        do {
            try database.run(transaction: {
                try database.delete(fromTable: Identity.tableName)
                try database.delete(fromTable: PreKey.tableName)
                try database.delete(fromTable: RatchetSenderKey.tableName)
                try database.delete(fromTable: SenderKey.tableName)
                try database.delete(fromTable: Session.tableName)
                try database.delete(fromTable: SignedPreKey.tableName)
            })
        } catch {
            Reporter.report(error: error)
        }
        AppGroupUserDefaults.Crypto.clearAll()
    }
    
}
