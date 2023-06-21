import Foundation

public class UserDatabaseDAO {
    
    public var db: Database {
        UserDatabase.current
    }
    
}

extension UserDatabaseDAO {
    
    // SQLite has a limitation on the number of parameters, and the maximum limit is `SQLITE_MAX_VARIABLE_NUMBER`
    // Before version 3.32.0 (2020-05-22), this limit was 999, and it was increased to 32766 afterward
    // Since users may choose to transfer more than 999 conversations during the device transfer process, in cases
    // where the limit is exceeded, it is necessary to query the relevant content in pages, with each page
    // not exceeding this quantity.
    public static let deviceTransferStride = 900
    
}
