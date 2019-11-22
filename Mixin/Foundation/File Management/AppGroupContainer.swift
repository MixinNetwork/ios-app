import Foundation

public enum AppGroupContainer {
    
    // In iOS, the value is nil when the group identifier is invalid.
    static let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)!
    
    public static let documentsUrl = AppGroupContainer.url.appendingPathComponent("Documents", isDirectory: true)
    
    public static let signalDatabaseUrl = documentsUrl.appendingPathComponent("signal.db", isDirectory: false)
    
    public static var accountUrl: URL {
        documentsUrl.appendingPathComponent(AccountAPI.shared.accountIdentityNumber, isDirectory: true)
    }
    
    public static var groupIconsUrl: URL {
        accountUrl.appendingPathComponent("Group", isDirectory: true)
            .appendingPathComponent("Icons", isDirectory: true)
    }
    
    public static var logUrl: URL {
        accountUrl.appendingPathComponent("Log", isDirectory: true)
    }
    
    public static var mixinDatabaseUrl: URL {
        accountUrl.appendingPathComponent("mixin.db", isDirectory: false)
    }
    
    public static var taskDatabaseUrl: URL {
        accountUrl.appendingPathComponent("task.db", isDirectory: false)
    }
    
}
