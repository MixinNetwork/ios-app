import Foundation

public class Web3DAO {
    
    public var db: Database {
        Web3Database.current
    }
    
    public static func deleteWalletsAddresses() {
        Web3Database.current.write { db in
            try db.execute(sql: "DELETE FROM wallets")
            try db.execute(sql: "DELETE FROM addresses")
        }
    }
    
}
