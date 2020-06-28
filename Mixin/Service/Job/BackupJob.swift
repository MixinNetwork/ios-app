import Foundation
import WCDBSwift
import MixinServices

class BackupJob: AsynchronousJob {

    static let sharedId = "backup"

    private let processQueue = DispatchQueue(label: "one.mixin.messenger.queue.backup")
    private let immediatelyBackup: Bool

    private var waitingUploadFiles = SafeDictionary<String, Upload>()
    private var uploadingFiles = SafeDictionary<String, Upload>()
    private var query = NSMetadataQuery()
    private var uploadedSize: Int64 = 0
    private var lastUpdateTime = Date()
    private var fileCount = 0
    private var preparedFileCount = 0
    private var needBackupDatabase = false
    private var isWaitingWifi = false

    private(set) var totalFileSize: Int64 = 0
    var totalUploadedSize: Int64 {
        uploadedSize + self.uploadingFiles.values.map { $0.uploadSize }.reduce(0, +)
    }

    var prepareProgress: Float64 {
        preparedFileCount == fileCount ? 1 : Float64(preparedFileCount) / Float64(fileCount)
    }

    init(immediatelyBackup: Bool = false) {
        self.immediatelyBackup = immediatelyBackup
        super.init()
    }

    override func finishJob() {
        stopQuery()
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.postOnMain(name: .BackupDidChange)
        super.finishJob()
    }

    override func getJobId() -> String {
         return BackupJob.sharedId
    }

    override func execute() -> Bool {
        guard FileManager.default.ubiquityIdentityToken != nil else {
            return false
        }
        guard let backupUrl = backupUrl else {
            return false
        }

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

        AppGroupUserDefaults.Account.hasUnfinishedBackup = true

        guard NetworkManager.shared.isReachableOnWiFi else {
            return false
        }

        fileCount = 0
        preparedFileCount = 0
        totalFileSize = 0
        uploadedSize = 0
        waitingUploadFiles = SafeDictionary<String, Upload>()
        uploadingFiles = SafeDictionary<String, Upload>()
        needBackupDatabase = !(AppGroupUserDefaults.Account.hasUnfinishedBackup && AppGroupUserDefaults.Account.hasFinishedDatabaseBackup)
        if needBackupDatabase {
            AppGroupUserDefaults.Account.hasFinishedDatabaseBackup = false
        }

        var localPaths = Set<String>()
        var cloudPaths = Set<String>()
        let startTime = Date()

        do {
            try FileManager.default.createDirectory(at: backupUrl, withIntermediateDirectories: true, attributes: nil)

            var categories: [AttachmentContainer.Category] = [.photos, .audios]
            if AppGroupUserDefaults.User.backupFiles {
                categories.append(.files)
            } else {
                let cloudFileURL = backupUrl.appendingPathComponent(AttachmentContainer.Category.files.pathComponent, isDirectory: true)
                try? FileManager.default.removeItem(at: cloudFileURL)
            }
            if AppGroupUserDefaults.User.backupVideos {
                categories.append(.videos)
            } else {
                let cloudVideoURL = backupUrl.appendingPathComponent(AttachmentContainer.Category.videos.pathComponent, isDirectory: true)
                try? FileManager.default.removeItem(at: cloudVideoURL)
            }

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
        } catch {
            reporter.report(error: error)
            return false
        }

        fileCount = localPaths.count
        for filename in localPaths {
            let localURL = AttachmentContainer.url.appendingPathComponent(filename)
            let cloudURL = backupUrl.appendingPathComponent(filename)
            let fileSize = FileManager.default.fileSize(localURL.path)
            let cloudExists = FileManager.default.fileExists(atPath: cloudURL.path)

            if cloudExists && FileManager.default.fileSize(cloudURL.path) == fileSize {
                uploadedSize += fileSize
            } else {
                waitingUploadFiles[localURL.lastPathComponent] = Upload(from: localURL, destination: cloudURL, fileSize: fileSize, isDatabase: false, percent: 0)
            }
            totalFileSize += fileSize
            preparedFileCount += 1
        }
        preparedFileCount = localPaths.count

        if isCancelled {
            return false
        }

        NotificationCenter.default.addObserver(self, selector: #selector(networkChanged), name: .NetworkDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(queryUpdateChanged), name: .NSMetadataQueryDidUpdate, object: nil)
        startQuery()

        backupDatabase()
        processQueue.async {
            self.backupNextFiles()
        }
        return true
    }

    private func backupDatabase() {
        guard let backupUrl = backupUrl else {
            return
        }

        let databaseCloudURL = backupUrl.appendingPathComponent(backupDatabaseName)
        if !needBackupDatabase || AppGroupUserDefaults.Account.hasFinishedDatabaseBackup {
            let databaseFileSize = FileManager.default.fileSize(databaseCloudURL.path)
            uploadedSize += databaseFileSize
            totalFileSize += databaseFileSize
            return
        }

        compressDatabase()
        let databaseFileSize = FileManager.default.fileSize(AppGroupContainer.mixinDatabaseUrl.path)
        if !FileManager.default.fileExists(atPath: databaseCloudURL.path) || FileManager.default.fileSize(databaseCloudURL.path) != databaseFileSize {
            let upload = Upload(from: AppGroupContainer.mixinDatabaseUrl, destination: databaseCloudURL, fileSize: databaseFileSize, isDatabase: true, percent: 0)
            uploadingFiles[backupDatabaseName] = upload
            copyToCloud(upload: upload, isDatabase: true)
        } else {
            uploadedSize += databaseFileSize
            AppGroupUserDefaults.Account.hasFinishedDatabaseBackup = true
        }
        totalFileSize += databaseFileSize
    }

    private func backupNextFiles() {
        guard uploadedSize < totalFileSize else {
            backupFinished()
            return
        }
        guard NetworkManager.shared.isReachableOnWiFi else {
            isWaitingWifi = true
            return
        }

        let files = waitingUploadFiles.keys
        for filename in files {
            guard let upload = waitingUploadFiles[filename] else {
                continue
            }

            if upload.destination.isUploaded {
                waitingUploadFiles.removeValue(forKey: filename)
                uploadedSize += upload.fileSize
            } else {
                uploadingFiles[filename] = upload
                copyToCloud(upload: upload)
                if uploadingFiles.count >= 10 {
                    return
                }
            }
        }

        if uploadedSize >= totalFileSize {
            backupFinished()
        }
    }

    func checkUploadStatus() {
        guard NetworkManager.shared.isReachableOnWiFi else {
            isWaitingWifi = true
            return
        }
        guard prepareProgress >= 1 else {
            return
        }
        guard uploadingFiles.count == 0 || -lastUpdateTime.timeIntervalSinceNow > Double(15) else {
            return
        }

        self.lastUpdateTime = Date()

        if uploadedSize >= totalFileSize {
            backupFinished()
        } else {
            stopQuery()
            startQuery()
            processQueue.async {
                let files = self.uploadingFiles.keys
                for filename in files {
                    if let upload = self.uploadingFiles[filename], upload.destination.isUploaded {
                        self.waitingUploadFiles.removeValue(forKey: filename)
                        self.uploadingFiles.removeValue(forKey: filename)
                        self.uploadedSize += upload.fileSize
                    }
                }
                self.backupNextFiles()
            }
        }
    }

    private func startQuery() {
        guard let backupUrl = backupUrl else {
            return
        }

        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        query.valueListAttributes = [ NSMetadataUbiquitousItemPercentUploadedKey,
                                      NSMetadataUbiquitousItemIsUploadingKey,
                                      NSMetadataUbiquitousItemUploadingErrorKey,
                                      NSMetadataUbiquitousItemIsUploadedKey]
        query.predicate = NSPredicate(format: "%K BEGINSWITH[c] %@ && kMDItemContentType != 'public.folder'", NSMetadataItemPathKey, backupUrl.path)
        self.query = query
        DispatchQueue.main.async {
            _ = query.start()
        }
    }

    private func stopQuery() {
        let query = self.query
        DispatchQueue.main.async {
            query.stop()
        }
    }

    private func backupFinished() {
        guard uploadedSize >= totalFileSize else {
            return
        }
        guard AppGroupUserDefaults.Account.hasUnfinishedBackup else {
            return
        }

        stopQuery()
        removeOldFiles()
        AppGroupUserDefaults.User.lastBackupDate = Date()
        AppGroupUserDefaults.User.lastBackupSize = totalFileSize
        AppGroupUserDefaults.Account.hasUnfinishedBackup = false
        AppGroupUserDefaults.Account.hasFinishedDatabaseBackup = false

        finishJob()
    }

    @objc private func networkChanged() {
        guard NetworkManager.shared.isReachableOnWiFi else {
            return
        }
        guard isWaitingWifi else {
            return
        }
        isWaitingWifi = false

        processQueue.async {
            self.backupNextFiles()
        }
    }

    @objc func queryUpdateChanged(notification: Notification) {
        guard let metadataItems = (notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem]) else {
            return
        }

        processQueue.async {
            self.lastUpdateTime = Date()

            for metadataItem in metadataItems {
                let name = metadataItem.value(forAttribute: NSMetadataItemFSNameKey) as? String
                let percent = (metadataItem.value(forAttribute: NSMetadataUbiquitousItemPercentUploadedKey) as? NSNumber)?.floatValue ?? 0
                let isUploaded = (metadataItem.value(forAttribute: NSMetadataUbiquitousItemIsUploadedKey) as? NSNumber)?.boolValue ?? false

                guard let filename = name, var upload = self.uploadingFiles[filename] else {
                    continue
                }

                if isUploaded {
                    if upload.isDatabase {
                        AppGroupUserDefaults.Account.hasFinishedDatabaseBackup = true
                    }
                    self.waitingUploadFiles.removeValue(forKey: filename)
                    self.uploadingFiles.removeValue(forKey: filename)
                    self.uploadedSize += upload.fileSize
                    self.backupNextFiles()
                } else {
                    upload.percent = percent
                    self.uploadingFiles[filename] = upload
                }
            }
        }
    }

    private func copyToCloud(upload: Upload, isDatabase: Bool = false) {
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let filename = upload.from.lastPathComponent
        uploadingFiles[filename] = upload
        do {
            try FileManager.default.copyItem(at: upload.from, to: tmpFile)
            if FileManager.default.fileExists(atPath: upload.destination.path) {
                try FileManager.default.removeItem(at: upload.destination)
            }
            try FileManager.default.setUbiquitous(true, itemAt: tmpFile, destinationURL: upload.destination)
        } catch {
            uploadingFiles.removeValue(forKey: filename)
            waitingUploadFiles.removeValue(forKey: filename)
            uploadedSize += upload.fileSize
            try? FileManager.default.removeItem(at: tmpFile)
            reporter.report(error: error)
        }
    }

    private func compressDatabase() {
        try? MixinDatabase.shared.database.prepareUpdateSQL(sql: "PRAGMA wal_checkpoint(FULL)").execute()
        if -AppGroupUserDefaults.Database.vacuumDate.timeIntervalSinceNow >= 86400 * 14 {
            AppGroupUserDefaults.Database.vacuumDate = Date()
            try? MixinDatabase.shared.database.prepareUpdateSQL(sql: "VACUUM").execute()
        }
    }

    private func removeOldFiles() {
        guard let backupUrl = backupUrl else {
            return
        }

        let files = ["mixin.backup.db",
                     "mixin.photos.zip",
                     "mixin.audios.zip"]

        let baseDir = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
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

    struct Upload {
        let from: URL
        let destination: URL
        let fileSize: Int64
        let isDatabase: Bool
        var percent: Float

        var uploadSize: Int64 {
            Int64(Float(fileSize) * percent / 100)
        }
    }
}
