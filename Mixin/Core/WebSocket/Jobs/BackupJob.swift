import Foundation
import Zip
import WCDBSwift

class BackupJob: BaseJob {
    
    static let sharedId = "backup"

    private let monitorQueue = DispatchQueue(label: "one.mixin.messenger.queue.backup")
    private let immediatelyBackup: Bool
    private var totalFileSize: Int64 = 0
    private var monitors = SafeDictionary<String, Int64>()
    private var isContinueBackup: Bool {
        return !isCancelled && NetworkManager.shared.isReachableOnWiFi
    }

    private(set) var preparing = true
    private(set) var backupTotalSize: Int64 = 0
    private(set) var backupSize: Int64 = 0
    private(set) var uploadTotalSize: Int64 = 0
    private(set) var uploadedSize: Int64 = 0

    init(immediatelyBackup: Bool = false) {
        self.immediatelyBackup = immediatelyBackup
        super.init()
    }

    override func getJobId() -> String {
         return BackupJob.sharedId
    }

    override func run() throws {
        guard FileManager.default.ubiquityIdentityToken != nil else {
            return
        }
        guard let backupDir = MixinFile.iCloudBackupDirectory else {
            return
        }

        if !immediatelyBackup {
            let lastBackupTime = CommonUserDefault.shared.lastBackupTime
            let now = Date().timeIntervalSince1970
            switch CommonUserDefault.shared.backupCategory {
            case .off:
                return
            case .daily:
                if now - lastBackupTime < 86400 {
                    return
                }
            case .weekly:
                if now - lastBackupTime < 86400 * 7 {
                    return
                }
            case .monthly:
                if now - lastBackupTime < 86400 * 30 {
                    return
                }
            }
        }

        do {
            try FileManager.default.createDirectoryIfNeeded(dir: backupDir)

            var categories: [MixinFile.ChatDirectory] = [.photos, .audios]
            if CommonUserDefault.shared.hasBackupFiles {
                categories.append(.files)
            } else {
                FileManager.default.removeDirectoryAndChildFiles(backupDir.appendingPathComponent(MixinFile.ChatDirectory.files.rawValue))
            }
            if CommonUserDefault.shared.hasBackupVideos {
                categories.append(.videos)
            } else {
                FileManager.default.removeDirectoryAndChildFiles(backupDir.appendingPathComponent(MixinFile.ChatDirectory.videos.rawValue))
            }

            var localPaths = Set<String>()
            var cloudPaths = Set<String>()
            let chatDir = MixinFile.rootDirectory.appendingPathComponent("Chat")

            for category in categories {
                let localDir = MixinFile.url(ofChatDirectory: category, filename: nil)
                let cloudDir = backupDir.appendingPathComponent(category.rawValue)

                if localDir.fileExists {
                    localPaths.formUnion(try FileManager.default.contentsOfDirectory(atPath: localDir.path).map { "\(category.rawValue)/\($0)" })
                }
                if cloudDir.fileExists {
                    cloudPaths.formUnion(try FileManager.default.contentsOfDirectory(atPath: cloudDir.path).map { "\(category.rawValue)/\($0)" })
                } else {
                    try FileManager.default.createDirectoryIfNeeded(dir: cloudDir)
                }
            }

            for path in cloudPaths {
                if !localPaths.contains(path) {
                    try? FileManager.default.removeItem(at: backupDir.appendingPathComponent(path))
                }
            }

            guard isContinueBackup else {
                return
            }

            var uploadPaths: [String] = []
            var backupPaths: [String] = []
            uploadedSize = 0
            uploadTotalSize = 0
            backupSize = 0
            backupTotalSize = 0
            monitors = SafeDictionary<String, Int64>()

            for filename in localPaths {
                let localURL = chatDir.appendingPathComponent(filename)
                let cloudURL = backupDir.appendingPathComponent(filename)
                let localFileSize = FileManager.default.fileSize(localURL.path)

                if !FileManager.default.fileExists(atPath: cloudURL.path) || FileManager.default.fileSize(cloudURL.path) != localFileSize {
                    backupPaths.append(filename)
                    uploadPaths.append(filename)
                    backupTotalSize += localFileSize
                    uploadTotalSize += localFileSize
                } else if FileManager.default.fileExists(atPath: cloudURL.path) && !cloudURL.isUploaded {
                    uploadPaths.append(filename)
                    uploadTotalSize += localFileSize
                }
            }
            totalFileSize = localPaths.map { chatDir.appendingPathComponent($0).fileSize }.reduce(0, +)

            guard isContinueBackup else {
                return
            }

            let semaphore = DispatchSemaphore(value: 0)
            let query = NSMetadataQuery()

            let observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: nil, queue: nil) { [weak self](notification) in
                guard let metadataItems = (notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem]) else {
                    return
                }
                self?.monitorQueue.async {
                    guard let weakSelf = self else {
                        return
                    }
                    guard weakSelf.isContinueBackup else {
                        // TODO
                        return
                    }

                    let monitors = weakSelf.monitors
                    for metadataItem in metadataItems {
                        let name = metadataItem.value(forAttribute: NSMetadataItemFSNameKey) as? String
                        let fileSize = (metadataItem.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber)?.int64Value ?? 0
                        let percent = (metadataItem.value(forAttribute: NSMetadataUbiquitousItemPercentUploadedKey) as? NSNumber)?.floatValue ?? 0
                        let isUploaded = (metadataItem.value(forAttribute: NSMetadataUbiquitousItemIsUploadedKey) as? NSNumber)?.boolValue ?? false

                        if let fileName = name, fileSize > 0, percent > 0, monitors[fileName] != nil {
                            monitors[fileName] = isUploaded ? fileSize : Int64(Float(fileSize) * percent / 100)
                        }
                    }
                    weakSelf.monitors = monitors
                    weakSelf.uploadedSize = monitors.values.map { $0 }.reduce(0, +)
                    if weakSelf.uploadedSize >= weakSelf.uploadTotalSize || weakSelf.isCancelled {
                        query.stop()
                        semaphore.signal()
                    }
                }
            }

            query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
            query.valueListAttributes = [ NSMetadataUbiquitousItemPercentUploadedKey,
                                          NSMetadataUbiquitousItemIsUploadingKey,
                                          NSMetadataUbiquitousItemUploadingErrorKey,
                                          NSMetadataUbiquitousItemIsUploadedKey]
            query.predicate = NSPredicate(format: "%K BEGINSWITH[c] %@ && kMDItemContentType != 'public.folder'", NSMetadataItemPathKey, backupDir.path)
            DispatchQueue.main.async {
                query.start()
            }

            backupDatabase(backupDir: backupDir)

            for path in backupPaths {
                guard isContinueBackup else {
                    return
                }
                let localURL = chatDir.appendingPathComponent(path)
                let cloudURL = backupDir.appendingPathComponent(path)
                copyToCloud(from: localURL, destination: cloudURL)
            }

            preparing = false
            
            removeOldFiles(backupDir: backupDir)
            CommonUserDefault.shared.lastBackupTime = Date().timeIntervalSince1970
            CommonUserDefault.shared.lastBackupSize = totalFileSize

            if uploadedSize == uploadTotalSize || !isContinueBackup {
                DispatchQueue.main.async {
                    query.stop()
                }
            } else {
                semaphore.wait()
            }
            NotificationCenter.default.removeObserver(observer)
        } catch {
            UIApplication.traceError(error)
        }
        NotificationCenter.default.postOnMain(name: .BackupDidChange)
    }

    private func backupDatabase(backupDir: URL) {
        let now = Date().timeIntervalSince1970
        try? MixinDatabase.shared.database.prepareUpdateSQL(sql: "PRAGMA wal_checkpoint(FULL)").execute()
        if now - DatabaseUserDefault.shared.lastVacuumTime >= 86400 * 7 {
            DatabaseUserDefault.shared.lastVacuumTime = now
            try? MixinDatabase.shared.database.prepareUpdateSQL(sql: "VACUUM").execute()
        }
        let databaseCloudURL = backupDir.appendingPathComponent(MixinFile.backupDatabaseName)
        let databaseFileSize = MixinFile.databaseURL.fileSize
        totalFileSize += databaseFileSize

        guard !FileManager.default.fileExists(atPath: databaseCloudURL.path) || FileManager.default.fileSize(databaseCloudURL.path) != FileManager.default.fileSize(MixinFile.databaseURL.path) else {
            return
        }

        guard copyToCloud(from: MixinFile.databaseURL, destination: databaseCloudURL) else {
            return
        }

        uploadTotalSize += databaseFileSize
        backupTotalSize += databaseFileSize
    }

    @discardableResult
    private func copyToCloud(from: URL, destination: URL) -> Bool {
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        monitors[destination.lastPathComponent] = 0
        do {
            try FileManager.default.copyItem(at: from, to: tmpFile)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.setUbiquitous(true, itemAt: tmpFile, destinationURL: destination)
            backupSize += from.fileSize
            return true
        } catch {
            monitors.removeValue(forKey: destination.lastPathComponent)
            if tmpFile.fileExists {
                try? FileManager.default.removeItem(at: tmpFile)
            }
            UIApplication.traceError(error)
            return false
        }
    }

    private func removeOldFiles(backupDir: URL) {
        let files = ["mixin.backup.db",
                     "mixin.\(MixinFile.ChatDirectory.photos.rawValue.lowercased()).zip",
            "mixin.\(MixinFile.ChatDirectory.audios.rawValue.lowercased()).zip"]
        for file in files {
            let cloudURL = backupDir.appendingPathComponent(file)
            if cloudURL.isStoredCloud {
                try? FileManager.default.removeItem(at: cloudURL)
            }
            let localURL = MixinFile.rootDirectory.appendingPathComponent(file)
            if localURL.fileExists {
                try? FileManager.default.removeItem(at: localURL)
            }
        }
    }
}
