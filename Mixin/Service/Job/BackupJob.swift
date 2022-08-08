import Foundation
import MixinServices

class BackupJob: CloudJob {
    
    var preparedProgress: Float64 {
        totalFileCount == 0 ? 0 : Float64(preparedFileCount) / Float64(totalFileCount)
    }
    
    private(set) var isPreparing = true
    
    private let immediatelyBackup: Bool
    private let maxConcurrentUploadCount = 10
    private let queue = DispatchQueue(label: "one.mixin.messenger.backup")
    
    private var totalFileCount = 0
    private var preparedFileCount = 0
    
    init(immediatelyBackup: Bool = false) {
        self.immediatelyBackup = immediatelyBackup
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(networkChanged), name: ReachabilityManger.reachabilityDidChangeNotification, object: nil)
    }
    
    override class var jobId: String {
        "backup"
    }
    
    override func execute() -> Bool {
        guard FileManager.default.ubiquityIdentityToken != nil else {
            return false
        }
        guard let backupUrl = backupUrl else {
            return false
        }
        guard isBackupNow() else {
            return false
        }
        AppGroupUserDefaults.Account.hasUnfinishedBackup = true
        guard prepare(backupUrl: backupUrl) else {
            return false
        }
        guard pendingFiles.count > 0 else {
            backupFinished()
            return true
        }
        guard isContinueProcessing else {
            return false
        }
        setupQuery(backupUrl: backupUrl)
        startQuery()
        queue.async(execute: backupNextFile)
        return true
    }
    
    override func setupQuery(backupUrl: URL) {
        super.setupQuery(backupUrl: backupUrl)
        query.valueListAttributes = [NSMetadataUbiquitousItemPercentUploadedKey,
                                     NSMetadataUbiquitousItemIsUploadedKey,
                                     NSMetadataUbiquitousItemUploadingErrorKey]
    }
    
    override func queryDidUpdate(notification: Notification) {
        guard let metadataItems = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem] else {
            return
        }
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            for item in metadataItems {
                guard
                    let filename = item.value(forAttribute: NSMetadataItemFSNameKey) as? String,
                    let file = self.processingFiles[filename]
                else {
                    continue
                }
                let isUploaded = item.value(forAttribute: NSMetadataUbiquitousItemIsUploadedKey) as? Bool ?? false
                if isUploaded {
                    self.processingFiles.removeValue(forKey: filename)
                    self.processedFileSize += file.size
                    if ReachabilityManger.shared.isReachableOnEthernetOrWiFi {
                        self.backupNextFile()
                    }
                } else {
                    let percent = item.value(forAttribute: NSMetadataUbiquitousItemPercentUploadedKey) as? Double ?? 0
                    self.processingFiles[filename]?.processedSize = Int64(Double(file.size) * percent / 100)
                }
                if let error = item.value(forAttribute: NSMetadataUbiquitousItemUploadingErrorKey) as? NSError {
                    Logger.general.error(category: "Backup", message: "Upload item at \(file.srcURL) failed, error: \(error)")
                }
            }
            if self.totalProcessedSize >= self.totalFileSize {
                self.backupFinished()
            }
        }
    }
    
}

extension BackupJob {
    
    private func isBackupNow() -> Bool {
        if !immediatelyBackup && !AppGroupUserDefaults.Account.hasUnfinishedBackup, let lastBackupDate = AppGroupUserDefaults.User.lastBackupDate {
            switch AppGroupUserDefaults.User.autoBackup {
            case .off:
                return false
            case .daily:
                if -lastBackupDate.timeIntervalSinceNow < 86400 {
                    return false
                }
            case .weekly:
                if -lastBackupDate.timeIntervalSinceNow < 86400 * 7 {
                    return false
                }
            case .monthly:
                if -lastBackupDate.timeIntervalSinceNow < 86400 * 30 {
                    return false
                }
            }
        }
        return true
    }
    
    private func prepare(backupUrl: URL) -> Bool {
        isPreparing = true
        defer {
            isPreparing = false
        }
        do {
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
                let localURL = AttachmentContainer.url(for: category, filename: nil)
                if localURL.fileExists {
                    localPaths.formUnion(try FileManager.default.contentsOfDirectory(atPath: localURL.path).map { "\(category.pathComponent)/\($0)" })
                }
                let cloudURL = backupUrl.appendingPathComponent(category.pathComponent)
                if cloudURL.fileExists {
                    cloudPaths.formUnion(try FileManager.default.contentsOfDirectory(atPath: cloudURL.path).map { "\(category.pathComponent)/\($0)" })
                } else {
                    try FileManager.default.createDirectory(at: cloudURL, withIntermediateDirectories: true, attributes: nil)
                }
            }
            for path in cloudPaths where !localPaths.contains(path) {
                try? FileManager.default.removeItem(at: backupUrl.appendingPathComponent(path))
            }
            
            totalFileCount = localPaths.count + 1
            
            func process(localURL: URL, cloudURL: URL, fileSize: Int64) {
                let isUploaded = FileManager.default.fileExists(atPath: cloudURL.path) && FileManager.default.fileSize(cloudURL.path) == fileSize
                if isUploaded {
                    processedFileSize += fileSize
                } else {
                    let file = File(srcURL: localURL, dstURL: cloudURL, size: fileSize)
                    pendingFiles[file.name] = file
                }
                totalFileSize += fileSize
                preparedFileCount += 1
            }
            
            let fileSize = databaseSizeAfterCompression()
            let localURL = AppGroupContainer.userDatabaseUrl
            let cloudURL = backupUrl.appendingPathComponent(backupDatabaseName)
            process(localURL: localURL, cloudURL: cloudURL, fileSize: fileSize)
            
            for path in localPaths {
                let localURL = AttachmentContainer.url.appendingPathComponent(path)
                let cloudURL = backupUrl.appendingPathComponent(path)
                let fileSize = FileManager.default.fileSize(localURL.path)
                process(localURL: localURL, cloudURL: cloudURL, fileSize: fileSize)
            }
            return true
        } catch {
            Logger.general.error(category: "BackupJob", message: "Prepare failed: \(error)")
            return false
        }
    }
    
    private func databaseSizeAfterCompression() -> Int64 {
        try? UserDatabase.current.writeAndReturnError { (db) -> Void in
            try db.checkpoint(.full, on: nil)
        }
        if AppGroupUserDefaults.Database.isFTSInitialized && -AppGroupUserDefaults.Database.vacuumDate.timeIntervalSinceNow >= 86400 * 14 {
            AppGroupUserDefaults.Database.vacuumDate = Date()
            try? UserDatabase.current.vacuum()
        }
        return FileManager.default.fileSize(AppGroupContainer.userDatabaseUrl.path)
    }
    
    private func copyFileToiCloud(_ file: File) {
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.copyItem(at: file.srcURL, to: tmpFile)
            if FileManager.default.fileExists(atPath: file.dstURL.path) {
                try FileManager.default.removeItem(at: file.dstURL)
            }
            try FileManager.default.setUbiquitous(true, itemAt: tmpFile, destinationURL: file.dstURL)
        } catch {
            processingFiles.removeValue(forKey: file.name)
            totalFileSize -= file.size
            if tmpFile.fileExists {
                try? FileManager.default.removeItem(at: tmpFile)
            }
            Logger.general.error(category: "BackupJob", message: "Failed to copy \(file.name) to iCloud, error: \(error)")
            reporter.report(error: error)
        }
    }
    
    private func backupNextFile() {
        guard let files = pendingFiles.values as? [File] else {
            return
        }
        for file in files {
            guard processingFiles.count < maxConcurrentUploadCount else {
                return
            }
            let name = file.name
            pendingFiles.removeValue(forKey: name)
            processingFiles[name] = file
            copyFileToiCloud(file)
        }
    }
    
    private func backupFinished() {
        stopQuery()
        deleteLegacyBackup()
        AppGroupUserDefaults.User.lastBackupDate = Date()
        AppGroupUserDefaults.User.lastBackupSize = totalFileSize
        AppGroupUserDefaults.Account.hasUnfinishedBackup = false
        NotificationCenter.default.post(onMainThread: BackupJob.backupDidChangeNotification, object: self)
        finishJob()
    }
    
    private func deleteLegacyBackup() {
        guard let backupUrl = backupUrl else {
            return
        }
        let baseDir = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let files = ["mixin.backup.db", "mixin.photos.zip", "mixin.audios.zip"]
        for file in files {
            let cloudURL = backupUrl.appendingPathComponent(file)
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
    
    @objc private func networkChanged() {
        guard ReachabilityManger.shared.isReachableOnEthernetOrWiFi else {
            return
        }
        queue.async(execute: backupNextFile)
    }
    
}

extension BackupJob {
    
    struct File: CloudJobFile {
        var srcURL: URL
        var dstURL: URL
        var size: Int64
        var processedSize: Int64 = 0
    }
    
}
