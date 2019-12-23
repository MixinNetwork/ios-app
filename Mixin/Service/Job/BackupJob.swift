import Foundation
import WCDBSwift

class BackupJob: BaseJob {
    
    static let sharedId = "backup"

    private let monitorQueue = DispatchQueue(label: "one.mixin.messenger.queue.backup")
    private let immediatelyBackup: Bool
    private var monitors = SafeDictionary<String, Int64>()
    private var withoutUploadSize: Int64 = 0
    private var realUploadedSize: Int64 = 0
    private var isStoppedQuery = false
    private var isContinueBackup: Bool {
        return !isCancelled && NetworkManager.shared.isReachableOnWiFi
    }

    private(set) var isBackingUp = true
    private(set) var totalFileSize: Int64 = 0
    private(set) var backupTotalSize: Int64 = 0
    private(set) var backupSize: Int64 = 0

    var uploadedSize: Int64 {
        return realUploadedSize + withoutUploadSize
    }

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
        guard let backupUrl = backupUrl else {
            return
        }

        if !immediatelyBackup && !AppGroupUserDefaults.Account.hasUnfinishedBackup, let lastBackupDate = AppGroupUserDefaults.User.lastBackupDate {
            switch AppGroupUserDefaults.User.autoBackup {
            case .off:
                return
            case .daily:
                if -lastBackupDate.timeIntervalSinceNow < 86400 {
                    return
                }
            case .weekly:
                if -lastBackupDate.timeIntervalSinceNow < 86400 * 7 {
                    return
                }
            case .monthly:
                if -lastBackupDate.timeIntervalSinceNow < 86400 * 30 {
                    return
                }
            }
        }

        AppGroupUserDefaults.Account.hasUnfinishedBackup = true
        
        try FileManager.default.createDirectory(at: backupUrl, withIntermediateDirectories: true, attributes: nil)
        
        var categories: [AttachmentContainer.Category] = [.photos, .audios]
        if AppGroupUserDefaults.User.backupFiles {
            categories.append(.files)
        } else {
            let url = backupUrl.appendingPathComponent(AttachmentContainer.Category.files.pathComponent, isDirectory: true)
            try? FileManager.default.removeItem(at: url)
        }
        if AppGroupUserDefaults.User.backupVideos {
            categories.append(.videos)
        } else {
            let url = backupUrl.appendingPathComponent(AttachmentContainer.Category.videos.pathComponent, isDirectory: true)
            try? FileManager.default.removeItem(at: url)
        }

        var localPaths = Set<String>()
        var cloudPaths = Set<String>()
        
        for category in categories {
            let localUrl = AttachmentContainer.url(for: category, filename: nil)
            let cloudUrl = backupUrl.appendingPathComponent(category.pathComponent)

            if localUrl.fileExists {
                localPaths.formUnion(try FileManager.default.contentsOfDirectory(atPath: localUrl.path).map { "\(category.pathComponent)/\($0)" })
            }
            if cloudUrl.fileExists {
                cloudPaths.formUnion(try FileManager.default.contentsOfDirectory(atPath: cloudUrl.path).map { "\(category.pathComponent)/\($0)" })
            } else {
                try FileManager.default.createDirectory(at: cloudUrl, withIntermediateDirectories: true, attributes: nil)
            }
        }

        for path in cloudPaths {
            if !localPaths.contains(path) {
                try? FileManager.default.removeItem(at: backupUrl.appendingPathComponent(path))
            }
        }

        guard isContinueBackup else {
            return
        }

        var uploadPaths: [String] = []
        var backupPaths: [String] = []
        monitors = SafeDictionary<String, Int64>()
        totalFileSize = 0
        withoutUploadSize = 0
        realUploadedSize = 0
        backupSize = 0
        backupTotalSize = 0
        isStoppedQuery = false
        isBackingUp = true

        for filename in localPaths {
            let localURL = AttachmentContainer.url.appendingPathComponent(filename)
            let cloudURL = backupUrl.appendingPathComponent(filename)
            let localFileSize = FileManager.default.fileSize(localURL.path)
            let cloudExists = FileManager.default.fileExists(atPath: cloudURL.path)

            if !cloudExists || FileManager.default.fileSize(cloudURL.path) != localFileSize {
                backupPaths.append(filename)
                backupTotalSize += localFileSize

                uploadPaths.append(filename)
            } else if cloudExists {
                if cloudURL.isUploaded {
                    withoutUploadSize += localFileSize
                } else {
                    uploadPaths.append(filename)
                }
            }
            totalFileSize += localFileSize
        }

        let databaseFileSize = getDatabaseFileSize()
        let databaseCloudURL = backupUrl.appendingPathComponent(backupDatabaseName)
        let isBackupDatabase = !FileManager.default.fileExists(atPath: databaseCloudURL.path) || FileManager.default.fileSize(databaseCloudURL.path) != databaseFileSize

        if !isBackupDatabase {
            withoutUploadSize += databaseFileSize
            totalFileSize += databaseFileSize
        }

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
                    weakSelf.stopQuery(query: query, semaphore: semaphore)
                    return
                }

                for metadataItem in metadataItems {
                    let name = metadataItem.value(forAttribute: NSMetadataItemFSNameKey) as? String
                    let fileSize = (metadataItem.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber)?.int64Value ?? 0
                    let percent = (metadataItem.value(forAttribute: NSMetadataUbiquitousItemPercentUploadedKey) as? NSNumber)?.floatValue ?? 0
                    let isUploaded = (metadataItem.value(forAttribute: NSMetadataUbiquitousItemIsUploadedKey) as? NSNumber)?.boolValue ?? false

                    if let fileName = name, fileSize > 0, percent > 0, weakSelf.monitors[fileName] != nil {
                        weakSelf.monitors[fileName] = isUploaded ? fileSize : Int64(Float(fileSize) * percent / 100)
                    }
                }
                weakSelf.realUploadedSize = weakSelf.monitors.values.map { $0 }.reduce(0, +)
                if weakSelf.uploadedSize >= weakSelf.totalFileSize {
                    weakSelf.stopQuery(query: query, semaphore: semaphore)
                }
            }
        }

        query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        query.valueListAttributes = [ NSMetadataUbiquitousItemPercentUploadedKey,
                                      NSMetadataUbiquitousItemIsUploadingKey,
                                      NSMetadataUbiquitousItemUploadingErrorKey,
                                      NSMetadataUbiquitousItemIsUploadedKey]
        query.predicate = NSPredicate(format: "%K BEGINSWITH[c] %@ && kMDItemContentType != 'public.folder'", NSMetadataItemPathKey, backupUrl.path)
        DispatchQueue.main.async {
            query.start()
        }

        if isBackupDatabase {
            copyToCloud(from: AppGroupContainer.mixinDatabaseUrl, destination: databaseCloudURL, isDatabase: true)
        }
        for path in backupPaths {
            guard isContinueBackup else {
                return
            }
            copyToCloud(from: AttachmentContainer.url.appendingPathComponent(path), destination: backupUrl.appendingPathComponent(path))
        }

        isBackingUp = false

        if uploadedSize >= totalFileSize || !isContinueBackup {
            DispatchQueue.main.async {
                query.stop()
            }
        } else {
            semaphore.wait()
        }
        NotificationCenter.default.removeObserver(observer)

        if uploadedSize >= totalFileSize {
            removeOldFiles(backupDir: backupUrl)
            AppGroupUserDefaults.User.lastBackupDate = Date()
            AppGroupUserDefaults.User.lastBackupSize = totalFileSize
            AppGroupUserDefaults.Account.hasUnfinishedBackup = false
        }

        NotificationCenter.default.postOnMain(name: .BackupDidChange)
    }

    private func getDatabaseFileSize() -> Int64 {
        try? MixinDatabase.shared.database.prepareUpdateSQL(sql: "PRAGMA wal_checkpoint(FULL)").execute()
        if -AppGroupUserDefaults.Database.vacuumDate.timeIntervalSinceNow >= 86400 * 14 {
            AppGroupUserDefaults.Database.vacuumDate = Date()
            try? MixinDatabase.shared.database.prepareUpdateSQL(sql: "VACUUM").execute()
        }
        return FileManager.default.fileSize(AppGroupContainer.mixinDatabaseUrl.path)
    }

    private func stopQuery(query: NSMetadataQuery, semaphore: DispatchSemaphore) {
        guard !isStoppedQuery else {
            return
        }
        isStoppedQuery = true
        query.stop()
        semaphore.signal()
    }

    private func copyToCloud(from: URL, destination: URL, isDatabase: Bool = false) {
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        monitors[destination.lastPathComponent] = 0
        do {
            try FileManager.default.copyItem(at: from, to: tmpFile)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.setUbiquitous(true, itemAt: tmpFile, destinationURL: destination)
            backupSize += from.fileSize
            if isDatabase {
                backupTotalSize += destination.fileSize
                totalFileSize += destination.fileSize
            }
        } catch {
            if !isDatabase {
                backupTotalSize -= from.fileSize
            }
            monitors.removeValue(forKey: destination.lastPathComponent)
            if tmpFile.fileExists {
                try? FileManager.default.removeItem(at: tmpFile)
            }
            Reporter.report(error: error)
        }
    }

    private func removeOldFiles(backupDir: URL) {
        let files = ["mixin.backup.db",
                     "mixin.photos.zip",
                     "mixin.audios.zip"]

        let baseDir = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        for file in files {
            let cloudURL = backupDir.appendingPathComponent(file)
            if cloudURL.isStoredCloud {
                try? FileManager.default.removeItem(at: cloudURL)
            }

            if file.hasSuffix(".zip") {
                let localURL = baseDir.appendingPathComponent(file)
                if localURL.fileExists {
                    try? FileManager.default.removeItem(at: localURL)
                }
            }
        }
    }
}
