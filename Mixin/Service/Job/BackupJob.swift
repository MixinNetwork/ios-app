import Foundation
import WCDBSwift
import MixinServices

class BackupJob: AsynchronousJob {

    static let sharedId = "backup"

    private var waitingUploadFiles = SafeDictionary<String, Int64>()
    private var uploadingFiles = SafeDictionary<String, Upload>()
    private var uploadedSize: Int64 = 0
    private var lastUpdateTime = Date()
    private var timer: Timer?
    private var isContinueBackup: Bool {
        return !isCancelled && NetworkManager.shared.isReachableOnWiFi
    }
    private var fileCount = 0
    private var preparedFileCount = 0

    private let processQueue = DispatchQueue(label: "one.mixin.messenger.queue.backup")
    private let immediatelyBackup: Bool
    private var query = NSMetadataQuery()

    private(set) var totalFileSize: Int64 = 0

    var backupProgress: ((Float64, Int64, Int64) -> Void)?

    init(immediatelyBackup: Bool = false) {
        self.immediatelyBackup = immediatelyBackup
        super.init()
    }

    deinit {
        print("===BackupJob...deinit...")
    }

    override func finishJob() {
        DispatchQueue.main.sync {
            query.stop()
        }
        timer?.invalidate()
        timer = nil
        NotificationCenter.default.removeObserver(self)
        super.finishJob()
        print("===BackupJob...finishJob...")
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

        fileCount = 0
        preparedFileCount = 0
        totalFileSize = 0
        uploadedSize = 0
        waitingUploadFiles = SafeDictionary<String, Int64>()
        uploadingFiles = SafeDictionary<String, Upload>()

        AppGroupUserDefaults.Account.hasUnfinishedBackup = true
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

        guard isContinueBackup else {
            return false
        }

        fileCount = localPaths.count
        startQuery()

        for filename in localPaths {
            let localURL = AttachmentContainer.url.appendingPathComponent(filename)
            let fileSize = FileManager.default.fileSize(localURL.path)
            waitingUploadFiles[filename] = fileSize
            totalFileSize += fileSize
            preparedFileCount += 1
        }
        preparedFileCount = localPaths.count

        print("=====spent time:\(-startTime.timeIntervalSinceNow)s...totalFileSize:\(totalFileSize.sizeRepresentation())...fileCount:\(fileCount)")

        guard isContinueBackup else {
            return false
        }

        let databaseFileSize = getDatabaseFileSize()
        let databaseCloudURL = backupUrl.appendingPathComponent(backupDatabaseName)
        if !FileManager.default.fileExists(atPath: databaseCloudURL.path) || FileManager.default.fileSize(databaseCloudURL.path) != databaseFileSize {
            totalFileSize += databaseFileSize
            let upload = Upload(from: AppGroupContainer.mixinDatabaseUrl, destination: databaseCloudURL, fileSize: databaseFileSize, percent: 0)
            uploadingFiles[backupDatabaseName] = upload
            copyToCloud(upload: upload, isDatabase: true)
        }

        processQueue.async {
            self.uploadNextFiles()
        }
        return true
    }

    private func uploadNextFiles() {
        guard let backupUrl = backupUrl else {
            return
        }

        let files = waitingUploadFiles.keys
        for filename in files {
            guard let fileSize = waitingUploadFiles[filename] else {
                continue
            }

            let localURL = AttachmentContainer.url.appendingPathComponent(filename)
            let cloudURL = backupUrl.appendingPathComponent(filename)
            let isUploaded = cloudURL.isUploaded

            if isUploaded {
                waitingUploadFiles.removeValue(forKey: filename)
                uploadedSize += fileSize
            } else {
                let upload = Upload(from: localURL, destination: cloudURL, fileSize: fileSize, percent: 0)
                uploadingFiles[filename] = upload
                copyToCloud(upload: upload)
                return
            }
        }
    }

    func checkUploadStatus() {
        print("...isContinueBackup:\(isContinueBackup)...lastUpdateTime:\(-lastUpdateTime.timeIntervalSinceNow)...uploadedSize:\(uploadedSize)...monitorQueue:\(totalFileSize.sizeRepresentation())")

        guard isContinueBackup else {
            return
        }
        guard -lastUpdateTime.timeIntervalSinceNow > 5 else {
            return
        }

        self.lastUpdateTime = Date()
        print("===checkUploadStatus...2....")
        startQuery(restart: true)

        uploadingFiles.removeAll()
        processQueue.async {
            self.uploadNextFiles()
        }
    }

    private func startQuery(restart: Bool = false) {
        guard let backupUrl = backupUrl else {
            return
        }
        if restart {
            NotificationCenter.default.removeObserver(self)
            DispatchQueue.main.sync {
                self.query.stop()
                self.timer?.invalidate()
                self.query = NSMetadataQuery()
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(queryUpdateChanged), name: .NSMetadataQueryDidUpdate, object: query)
        query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        query.valueListAttributes = [ NSMetadataUbiquitousItemPercentUploadedKey,
                                      NSMetadataUbiquitousItemIsUploadingKey,
                                      NSMetadataUbiquitousItemUploadingErrorKey,
                                      NSMetadataUbiquitousItemIsUploadedKey]
        query.predicate = NSPredicate(format: "%K BEGINSWITH[c] %@ && kMDItemContentType != 'public.folder'", NSMetadataItemPathKey, backupUrl.path)
        DispatchQueue.main.sync {
            self.query.start()
            self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.calculateUploadProgress), userInfo: nil, repeats: true)
        }
    }

    @objc func calculateUploadProgress() {
        let uploadedSize = self.uploadedSize + self.uploadingFiles.values.map { $0.uploadSize }.reduce(0, +)
        let prepareProgress: Float64 = preparedFileCount == fileCount ? 100 : Float64(preparedFileCount) / Float64(fileCount)

        backupProgress?(prepareProgress, uploadedSize, totalFileSize)

        print("===prepareProgress:\(NumberFormatter.simplePercentage.stringFormat(value: prepareProgress))")

        if uploadedSize >= totalFileSize {
            self.timer?.invalidate()
            DispatchQueue.main.sync {
                self.query.stop()
            }
            finishJob()
        }
    }

    @objc func queryUpdateChanged(notification: Notification) {
        guard (notification.object as? NSMetadataQuery) == query else {
            return
        }
        guard let metadataItems = (notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem]) else {
            return
        }

        processQueue.async {
            self.lastUpdateTime = Date()

            for metadataItem in metadataItems {
                let url = metadataItem.value(forAttribute: NSMetadataItemURLKey) as? URL
                let percent = (metadataItem.value(forAttribute: NSMetadataUbiquitousItemPercentUploadedKey) as? NSNumber)?.floatValue ?? 0
                let isUploaded = (metadataItem.value(forAttribute: NSMetadataUbiquitousItemIsUploadedKey) as? NSNumber)?.boolValue ?? false

                guard let filename = url?.lastDirAndFilename, var upload = self.uploadingFiles[filename] else {
                    continue
                }

                if isUploaded {
                    self.waitingUploadFiles.removeValue(forKey: filename)
                    self.uploadedSize += upload.fileSize
                    self.uploadNextFiles()
                } else {
                    upload.percent = percent
                    self.uploadingFiles[filename] = upload
                }
            }
        }
    }

    private func copyToCloud(upload: Upload, isDatabase: Bool = false) {
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let filename = upload.from.lastDirAndFilename
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

    private func getDatabaseFileSize() -> Int64 {
        try? MixinDatabase.shared.database.prepareUpdateSQL(sql: "PRAGMA wal_checkpoint(FULL)").execute()
        if -AppGroupUserDefaults.Database.vacuumDate.timeIntervalSinceNow >= 86400 * 14 {
            AppGroupUserDefaults.Database.vacuumDate = Date()
            try? MixinDatabase.shared.database.prepareUpdateSQL(sql: "VACUUM").execute()
        }
        return FileManager.default.fileSize(AppGroupContainer.mixinDatabaseUrl.path)
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

    struct Upload {
        let from: URL
        let destination: URL
        let fileSize: Int64
        var percent: Float

        var uploadSize: Int64 {
            Int64(Float(fileSize) * percent / 100)
        }
    }
}

fileprivate extension URL {

    var lastDirAndFilename: String {
        let count = pathComponents.count
        return count > 2 ? "\(pathComponents[count-2])/\(pathComponents[count-1])" : lastPathComponent
    }

}
