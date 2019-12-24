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
    public static func migrate() {
        guard let userDomainDocumentUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        do {
            if FileManager.default.fileExists(atPath: documentsUrl.path, isDirectory: nil) {
                try FileManager.default.removeItem(at: documentsUrl)
            }
            try FileManager.default.copyItem(at: userDomainDocumentUrl, to: documentsUrl)
            let enumerator = FileManager.default.enumerator(atPath: userDomainDocumentUrl.path)
            while let file = enumerator?.nextObject() as? String {
                let url = userDomainDocumentUrl.appendingPathComponent(file)
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            print(error)
        }
    }
    
}
