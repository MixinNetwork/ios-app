import Foundation

public class UserDatabaseDAO {
    
    public var db: Database {
        UserDatabase.current
    }
    
}
