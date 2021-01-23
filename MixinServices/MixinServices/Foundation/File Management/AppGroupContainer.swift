import Foundation

public enum AppGroupContainer {
    
    // In iOS, the value is nil when the group identifier is invalid.
    static let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)!
    
    public static let documentsUrl: URL = {
        let url = AppGroupContainer.url.appendingPathComponent("Documents", isDirectory: true)
        try? FileManager.default.createDirectoryIfNotExists(atPath: url.path)
        return url
    }()
    
    public static let signalDatabaseUrl = documentsUrl.appendingPathComponent("signal.db", isDirectory: false)
    
    public static var accountUrl: URL {
        let url = documentsUrl.appendingPathComponent(myIdentityNumber, isDirectory: true)
        try? FileManager.default.createDirectoryIfNotExists(atPath: url.path)
        return url
    }
    
    public static var groupIconsUrl: URL {
        let url = accountUrl
            .appendingPathComponent("Group", isDirectory: true)
            .appendingPathComponent("Icons", isDirectory: true)
        try? FileManager.default.createDirectoryIfNotExists(atPath: url.path)
        return url
    }
    
    public static var logUrl: URL {
        let url = accountUrl.appendingPathComponent("Log", isDirectory: true)
        try? FileManager.default.createDirectoryIfNotExists(atPath: url.path)
        return url
    }
    
    public static var userDatabaseUrl: URL {
        accountUrl.appendingPathComponent("mixin.db", isDirectory: false)
    }
    
    public static var taskDatabaseUrl: URL {
        accountUrl.appendingPathComponent("task.db", isDirectory: false)
    }
    
    @available(iOSApplicationExtension, unavailable)
    public static func migrateIfNeeded() {
        guard !AppGroupUserDefaults.isDocumentsMigrated else {
            return
        }
        defer {
            AppGroupUserDefaults.isDocumentsMigrated = true
        }
        guard let localDocumentUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        guard let enumerator = FileManager.default.enumerator(atPath: localDocumentUrl.path) else {
            return
        }
        while let file = enumerator.nextObject() as? String {
            let src = localDocumentUrl.appendingPathComponent(file)
            let dst = documentsUrl.appendingPathComponent(file)
            do {
                try FileManager.default.moveItem(at: src, to: dst)
            } catch {
                reporter.report(error: error)
            }
        }
    }
    
}
