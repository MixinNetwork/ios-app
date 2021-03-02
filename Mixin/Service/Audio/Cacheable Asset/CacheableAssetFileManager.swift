import Foundation
import MixinServices

class CacheableAssetFileManager {
    
    enum Error: Swift.Error {
        case inaccessibleCacheFolder
    }
    
    struct FilePack {
        let assetURL: URL
        let isAssetFileNewlyCreated: Bool
        let fileDescriptionURL: URL
    }
    
    static let shared = CacheableAssetFileManager()
    
    private let maxFileAge: TimeInterval = 14 * secondsPerDay
    private let queue = DispatchQueue(label: "one.mixin.messenger.CacheableAssetFileManager")
    private let fileManager = FileManager.default
    
    private var cacheURL: URL? {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("CacheableAssets", isDirectory: true)
    }
    
    init() {
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(applicationWillTerminate(_:)),
                           name: UIApplication.willTerminateNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(applicationDidEnterBackground(_:)),
                           name: UIApplication.didEnterBackgroundNotification,
                           object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func filePack(for id: String) throws -> FilePack {
        guard let cacheURL = cacheURL else {
            throw Error.inaccessibleCacheFolder
        }
        try createFileIfNotExists(at: cacheURL, isDirectory: true)
        
        let assetURL = cacheURL.appendingPathComponent(id, isDirectory: false)
        let isAssetFileNewlyCreated = try createFileIfNotExists(at: assetURL, isDirectory: false)
        let descriptionURL = cacheURL.appendingPathComponent(id + ".cafd", isDirectory: false)
        
        return FilePack(assetURL: assetURL,
                        isAssetFileNewlyCreated: isAssetFileNewlyCreated,
                        fileDescriptionURL: descriptionURL)
    }
    
    // Returns true if the file is newly created, false if the file already exists
    @discardableResult
    private func createFileIfNotExists(at url: URL, isDirectory shouldBeDirectory: Bool) throws -> Bool {
        var isDirectory = ObjCBool(false)
        
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue == shouldBeDirectory {
                return false
            } else {
                try fileManager.removeItem(at: url)
            }
        }
        
        if shouldBeDirectory {
            try fileManager.createDirectory(at: url,
                                            withIntermediateDirectories: true,
                                            attributes: nil)
            return true
        } else {
            try Data().write(to: url)
            return true
        }
    }
    
}

// MARK: - Cache cleaning
extension CacheableAssetFileManager {
    
    @objc private func applicationWillTerminate(_ notification: Notification) {
        deleteOldAssetCache(completion: nil)
    }
    
    @objc private func applicationDidEnterBackground(_ notification: Notification) {
        let application = UIApplication.shared
        var id = UIBackgroundTaskIdentifier.invalid
        id = application.beginBackgroundTask {
            guard id != .invalid else {
                return
            }
            application.endBackgroundTask(id)
            id = .invalid
        }
        deleteOldAssetCache {
            guard id != .invalid else {
                return
            }
            application.endBackgroundTask(id)
            id = .invalid
        }
    }
    
    private func deleteOldAssetCache(completion: (() -> Void)?) {
        let fileManager = self.fileManager
        queue.async {
            if let url = self.cacheURL {
                let expirationDate = Date(timeIntervalSinceNow: -self.maxFileAge)
                let enumerator = fileManager.enumerator(at: url,
                                                        includingPropertiesForKeys: [.contentAccessDateKey],
                                                        options: .skipsHiddenFiles,
                                                        errorHandler: nil)
                while let url = enumerator?.nextObject() {
                    guard let url = url as? URL else {
                        continue
                    }
                    guard let values = try? url.resourceValues(forKeys: [.contentAccessDateKey]) else {
                        return
                    }
                    guard let date = values.contentAccessDate else {
                        continue
                    }
                    if date < expirationDate {
                        try? fileManager.removeItem(at: url)
                    }
                }
            }
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
        }
    }
    
}
