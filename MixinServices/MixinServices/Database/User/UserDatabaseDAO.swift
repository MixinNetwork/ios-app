import Foundation

public class UserDatabaseDAO {
    
    public var db: Database {
        UserDatabase.current
    }
    
}

extension UserDatabaseDAO {
    
    // To prevent excessive memory allocations,
    // the maximum value of a host parameter number is SQLITE_MAX_VARIABLE_NUMBER,
    // which defaults to 999 for SQLite versions prior to 3.32.0 (2020-05-22) or 32766 for SQLite versions after 3.32.0.
    // Therefore, we default to grouping with 900
    public static let strideForDeviceTransfer = 900
    
}
