import Foundation

public enum AppGroupContainer {
    
    // In iOS, the value is nil when the group identifier is invalid.
    static let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)!
    
    public static let documentsUrl = AppGroupContainer.url.appendingPathComponent("Documents", isDirectory: true)
    
    public static let signalDatabaseUrl = documentsUrl.appendingPathComponent("signal.db", isDirectory: false)
    
    public static var accountUrl: URL {
        documentsUrl.appendingPathComponent(myIdentityNumber, isDirectory: true)
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
        if !FileManager.default.fileExists(atPath: documentsUrl.path) {
            do {
                try FileManager.default.createDirectory(at: documentsUrl, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error)
            }
        }
        while let file = enumerator.nextObject() as? String {
            let src = localDocumentUrl.appendingPathComponent(file)
            let dst = documentsUrl.appendingPathComponent(file)
            do {
                try FileManager.default.moveItem(at: src, to: dst)
            } catch {
                print(error)
            }
        }
    }
    
}
