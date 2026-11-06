import Foundation
import GRDB
import MixinServices

final class BackupJob: BaseJob, @unchecked Sendable {
    
    static let sharedID = "backup"
    static let backupDidChangeNotification = Notification.Name("one.mixin.messenger.Application.backupDidChange")
    
    @Synchronized(value: true) private(set) var isBackingUp: Bool
    @Synchronized(value: 0) private(set) var totalFileSize: Int64
    @Synchronized(value: 0) private(set) var backupTotalSize: Int64
    @Synchronized(value: 0) private(set) var backupSize: Int64
    @Synchronized(value: 0) private(set) var uploadedSize: Int64
    
    private let immediatelyBackup: Bool
    
    private var isContinueBackup: Bool {
        !isCancelled && ReachabilityManger.shared.isReachableOnEthernetOrWiFi
    }
    
    init(immediatelyBackup: Bool) {
        self.immediatelyBackup = immediatelyBackup
        super.init()
    }
    
    override func getJobId() -> String {
        Self.sharedID
    }
    
    override func run() throws {
        // All file and iCloud work belongs to the job's background operation.
        dispatchPrecondition(condition: .notOnQueue(.main))
        defer {
            isBackingUp = false
            NotificationCenter.default.post(onMainThread: Self.backupDidChangeNotification, object: self)
        }
        guard isContinueBackup, FileManager.default.ubiquityIdentityToken != nil else {
            return
        }
        if !immediatelyBackup && !AppGroupUserDefaults.Account.hasUnfinishedBackup {
            let interval: TimeInterval
            switch AppGroupUserDefaults.User.autoBackup {
            case .off:
                return
            case .daily:
                interval = 86400
            case .weekly:
                interval = 86400 * 7
            case .monthly:
                interval = 86400 * 30
            }
            if let date = AppGroupUserDefaults.User.lastBackupDate, -date.timeIntervalSinceNow < interval {
                return
            }
        }
        guard let backupURL = backupUrl else {
            return
        }
        AppGroupUserDefaults.Account.hasUnfinishedBackup = true
        
        do {
            let manager = FileManager.default
            try manager.createDirectory(at: backupURL, withIntermediateDirectories: true, attributes: nil)
            let temporaryDirectory = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try manager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true, attributes: nil)
            defer {
                try? manager.removeItem(at: temporaryDirectory)
            }
            
            // A checkpoint followed by copying the live SQLite file can race with writes,
            // and equal file sizes do not imply equal database contents. Always take a snapshot.
            let databaseURL = temporaryDirectory.appendingPathComponent(backupDatabaseName)
            let database = try DatabaseQueue(path: databaseURL.path)
            do {
                let snapshot = try UserDatabase.current.makeSnapshot()
                try snapshot.backup(to: database, pagesPerStep: 256) { _ in
                    guard self.isContinueBackup else {
                        throw CancellationError()
                    }
                }
            }
            try database.close()
            guard let databaseFileSize = try databaseURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
                throw CocoaError(.fileReadUnknown)
            }
            
            var categories: [AttachmentContainer.Category] = [.photos, .audios]
            if AppGroupUserDefaults.User.backupFiles {
                categories.append(.files)
            }
            if AppGroupUserDefaults.User.backupVideos {
                categories.append(.videos)
            }
            var filesToCopy: [(source: URL, destination: URL)] = []
            var expectedFiles: [URL: Int64] = [:]
            var obsoleteFiles: [URL] = []
            
            for category in categories {
                guard isContinueBackup else {
                    return
                }
                let localURL = AttachmentContainer.url(for: category, filename: nil)
                let cloudURL = backupURL.appendingPathComponent(category.pathComponent, isDirectory: true)
                try manager.createDirectory(at: cloudURL, withIntermediateDirectories: true, attributes: nil)
                let filenames = manager.fileExists(atPath: localURL.path)
                    ? try manager.contentsOfDirectory(atPath: localURL.path) : []
                var localNames = Set<String>()
                for filename in filenames {
                    guard isContinueBackup else {
                        return
                    }
                    let source = localURL.appendingPathComponent(filename)
                    let values = try source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                    guard values.isRegularFile == true, let size = values.fileSize else {
                        continue
                    }
                    localNames.insert(filename)
                    let destination = cloudURL.appendingPathComponent(filename)
                    expectedFiles[destination] = Int64(size)
                    if !manager.fileExists(atPath: destination.path) || destination.fileSize != Int64(size) {
                        filesToCopy.append((source, destination))
                        backupTotalSize += Int64(size)
                    }
                }
                for filename in try manager.contentsOfDirectory(atPath: cloudURL.path) where !localNames.contains(filename) {
                    obsoleteFiles.append(cloudURL.appendingPathComponent(filename))
                }
            }
            for category in [AttachmentContainer.Category.files, .videos] where !categories.contains(category) {
                obsoleteFiles.append(backupURL.appendingPathComponent(category.pathComponent, isDirectory: true))
            }
            
            let databaseDestination = backupURL.appendingPathComponent(backupDatabaseName)
            expectedFiles[databaseDestination] = Int64(databaseFileSize)
            backupTotalSize += Int64(databaseFileSize)
            totalFileSize = expectedFiles.values.reduce(0, +)
            
            for file in filesToCopy {
                guard isContinueBackup else {
                    return
                }
                try copyToCloud(from: file.source, destination: file.destination)
                backupSize += expectedFiles[file.destination] ?? 0
            }
            guard isContinueBackup else {
                return
            }
            try copyToCloud(from: databaseURL, destination: databaseDestination)
            backupSize += Int64(databaseFileSize)
            isBackingUp = false
            
            let monitor = UploadMonitor(
                files: expectedFiles,
                query: NSMetadataQuery(),
                readUploadStatus: { path in
                    do {
                        let values = try URL(fileURLWithPath: path).resourceValues(forKeys: [
                            .fileSizeKey,
                            .ubiquitousItemIsUploadedKey,
                            .ubiquitousItemUploadingErrorKey,
                        ])
                        return UploadStatus(
                            size: values.fileSize.map(Int64.init),
                            isUploaded: values.ubiquitousItemIsUploaded == true,
                            error: values.ubiquitousItemUploadingError.map(UploadStatus.Failure.upload),
                        )
                    } catch {
                        return UploadStatus(size: nil, isUploaded: false, error: .resourceRead(error))
                    }
                },
            )
            let completed = try monitor.wait(
                stallTimeout: 600,
                refreshInterval: 5,
                shouldContinue: { self.isContinueBackup },
                updateProgress: { self.uploadedSize = $0 },
            )
            guard completed, isContinueBackup else {
                return
            }
            
            // Retain the previous backup's files until every new file has uploaded.
            for url in obsoleteFiles {
                guard isContinueBackup else {
                    return
                }
                try? manager.removeItem(at: url)
            }
            for filename in ["mixin.backup.db", "mixin.photos.zip", "mixin.audios.zip"] {
                try? manager.removeItem(at: backupURL.appendingPathComponent(filename))
                if filename.hasSuffix(".zip"),
                   let documentsURL = manager.urls(for: .documentDirectory, in: .userDomainMask).first {
                    try? manager.removeItem(at: documentsURL.appendingPathComponent(filename))
                }
            }
            AppGroupUserDefaults.User.lastBackupDate = Date()
            AppGroupUserDefaults.User.lastBackupSize = totalFileSize
            AppGroupUserDefaults.Account.hasUnfinishedBackup = false
        } catch is CancellationError {
            return
        } catch {
            reporter.report(error: error)
            throw error
        }
    }
    
    private func copyToCloud(from source: URL, destination: URL) throws {
        let manager = FileManager.default
        let temporaryURL = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let stagingURL = destination.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).backup")
        defer {
            try? manager.removeItem(at: temporaryURL)
            try? manager.removeItem(at: stagingURL)
        }
        try manager.copyItem(at: source, to: temporaryURL)
        try manager.setUbiquitous(true, itemAt: temporaryURL, destinationURL: stagingURL)
        
        // Stage first so a failed copy never deletes the existing backup.
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var replacementError: Error?
        coordinator.coordinate(
            writingItemAt: stagingURL,
            options: .forMoving,
            writingItemAt: destination,
            options: .forReplacing,
            error: &coordinationError,
        ) { stagedURL, url in
            do {
                if manager.fileExists(atPath: url.path) || manager.isUbiquitousItem(at: url) {
                    _ = try manager.replaceItemAt(url, withItemAt: stagedURL, options: .usingNewMetadataOnly)
                } else {
                    try manager.moveItem(at: stagedURL, to: url)
                }
            } catch {
                replacementError = error
            }
        }
        if let coordinationError {
            throw coordinationError
        }
        if let replacementError {
            throw replacementError
        }
    }
    
}

extension BackupJob {
    
    struct UploadStatus {
        
        enum Failure {
            case resourceRead(Error)
            case upload(Error)
        }
        
        let size: Int64?
        let isUploaded: Bool
        let error: Failure?
    }
    
    struct UploadProgress {
        
        private(set) var pendingFiles: [String: Int64]
        private(set) var uploadedSize: Int64 = 0
        
        private var uploadedBytes: [String: Int64] = [:]
        
        init(files: [URL: Int64]) {
            pendingFiles = Dictionary(uniqueKeysWithValues: files.map { (BackupJob.normalizedUploadPath($0.key), $0.value) })
        }
        
        mutating func update(path: String, size: Int64, percent: Double, isUploaded: Bool) {
            guard let expectedSize = pendingFiles[path], size == expectedSize else {
                return
            }
            let fraction = percent.isFinite ? min(1, max(0, percent / 100)) : 0
            let bytes = isUploaded ? expectedSize : Int64(Double(expectedSize) * fraction)
            uploadedSize += bytes - (uploadedBytes[path] ?? 0)
            uploadedBytes[path] = bytes
            if isUploaded {
                pendingFiles.removeValue(forKey: path)
                uploadedBytes.removeValue(forKey: path)
            }
        }
        
    }
    
    static func normalizedUploadPath(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }
    
    final class UploadMonitor {
        
        private let query: NSMetadataQuery
        private let queue = OperationQueue()
        private let condition = NSCondition()
        private let uploadStatusQueue = DispatchQueue(label: "one.mixin.messenger.queue.backup.upload-status", qos: .utility)
        private let readUploadStatus: (String) -> UploadStatus
        
        private var progress: UploadProgress
        private var error: Error?
        private var retryableFailures: [String: UploadStatus.Failure] = [:]
        private var lastProgressTime = ProcessInfo.processInfo.systemUptime
        private var isRefreshing = false
        private var isStopped = false
        
        init(
            files: [URL: Int64],
            query: NSMetadataQuery,
            readUploadStatus: @escaping (String) -> UploadStatus,
        ) {
            self.query = query
            self.readUploadStatus = readUploadStatus
            progress = UploadProgress(files: files)
            queue.name = "one.mixin.messenger.queue.backup.metadata"
            queue.maxConcurrentOperationCount = 1
            queue.qualityOfService = .utility
            query.operationQueue = queue
            query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
            // iCloud's indexed paths can differ from filesystem paths. Filter expected
            // paths locally, and avoid content-type predicates that resolve types via XPC.
            query.predicate = NSPredicate(format: "%K LIKE '*'", NSMetadataItemFSNameKey)
        }
        
        func wait(
            stallTimeout: TimeInterval,
            refreshInterval: TimeInterval,
            shouldContinue: () -> Bool,
            updateProgress: (Int64) -> Void,
        ) throws -> Bool {
            let center = NotificationCenter.default
            let gathered = center.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: nil) { [weak self] _ in
                guard let self else {
                    return
                }
                // enumerateResults disables and reenables updates internally.
                self.query.enumerateResults { result, _, _ in
                    if let item = result as? NSMetadataItem {
                        self.consume(item)
                    }
                }
            }
            let updated = center.addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: nil) { [weak self] notification in
                let added = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] ?? []
                let changed = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem] ?? []
                for item in added + changed {
                    self?.consume(item)
                }
            }
            defer {
                condition.lock()
                isStopped = true
                condition.unlock()
                center.removeObserver(gathered)
                center.removeObserver(updated)
                queue.addOperation { [query] in
                    query.stop()
                }
            }
            queue.addOperation { [self] in
                if !query.start() {
                    condition.lock()
                    error = CocoaError(.fileReadUnknown)
                    condition.signal()
                    condition.unlock()
                }
            }
            
            var nextRefreshTime: TimeInterval = 0
            while shouldContinue() {
                condition.lock()
                let bytes = progress.uploadedSize
                let completed = progress.pendingFiles.isEmpty
                let failure = error
                let retryableFailure = retryableFailures.values.first
                // A silent iCloud stall must not occupy the serial backup queue forever.
                let stalled = ProcessInfo.processInfo.systemUptime - lastProgressTime >= stallTimeout
                let now = ProcessInfo.processInfo.systemUptime
                let shouldRefresh = !isRefreshing && now >= nextRefreshTime
                if shouldRefresh {
                    isRefreshing = true
                    nextRefreshTime = now + refreshInterval
                }
                condition.unlock()
                updateProgress(bytes)
                if let failure {
                    throw failure
                }
                if completed {
                    return true
                }
                if stalled {
                    switch retryableFailure {
                    case .resourceRead(let error), .upload(let error):
                        throw error
                    case nil:
                        throw URLError(.timedOut)
                    }
                }
                if shouldRefresh {
                    uploadStatusQueue.async { [self] in
                        condition.lock()
                        let files = progress.pendingFiles
                        condition.unlock()
                        defer {
                            condition.lock()
                            isRefreshing = false
                            condition.signal()
                            condition.unlock()
                        }
                        for (path, _) in files {
                            condition.lock()
                            let active = !isStopped && error == nil
                            condition.unlock()
                            guard active else {
                                return
                            }
                            let status = readUploadStatus(path)
                            recordProgress(
                                path: path,
                                size: status.size,
                                percent: 0,
                                isUploaded: status.isUploaded,
                                uploadingError: status.error,
                            )
                        }
                    }
                }
                condition.lock()
                _ = condition.wait(until: Date().addingTimeInterval(1))
                condition.unlock()
            }
            return false
        }
        
        private func consume(_ item: NSMetadataItem) {
            guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else {
                return
            }
            let size = (item.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber)?.int64Value
            let percent = (item.value(forAttribute: NSMetadataUbiquitousItemPercentUploadedKey) as? NSNumber)?.doubleValue ?? 0
            let isUploaded = (item.value(forAttribute: NSMetadataUbiquitousItemIsUploadedKey) as? NSNumber)?.boolValue ?? false
            let uploadingError = item.value(forAttribute: NSMetadataUbiquitousItemUploadingErrorKey) as? Error
            // Metadata supplies progress; only the current URL status confirms completion.
            recordProgress(
                path: BackupJob.normalizedUploadPath(URL(fileURLWithPath: path)),
                size: size,
                percent: isUploaded ? 100 : percent,
                isUploaded: false,
                uploadingError: uploadingError.map(UploadStatus.Failure.upload),
            )
        }
        
        private func recordProgress(
            path: String,
            size: Int64?,
            percent: Double,
            isUploaded: Bool,
            uploadingError: UploadStatus.Failure?,
        ) {
            var retryMessage: String?
            condition.lock()
            defer {
                condition.signal()
                condition.unlock()
                if let retryMessage {
                    Logger.general.info(category: "Backup", message: retryMessage)
                }
            }
            guard !isStopped, progress.pendingFiles[path] != nil else {
                return
            }
            if let uploadingError {
                switch uploadingError {
                case .upload(let failure):
                    let cocoaError = failure as NSError
                    if cocoaError.domain == NSCocoaErrorDomain {
                        switch cocoaError.code {
                        case NSUbiquitousFileNotUploadedDueToQuotaError,
                             NSFileReadNoPermissionError,
                             NSFileWriteNoPermissionError,
                             NSFileWriteOutOfSpaceError,
                             NSFileWriteVolumeReadOnlyError:
                            error = failure
                            return
                        default:
                            break
                        }
                    }
                case .resourceRead:
                    break
                }
                // Status observations can fail while iCloud is retrying. Preserve the
                // failure for the stall deadline instead of failing on the first read.
                if retryableFailures[path] == nil {
                    retryMessage = "Retrying upload status for \(URL(fileURLWithPath: path).lastPathComponent): \(uploadingError)"
                }
                retryableFailures[path] = uploadingError
                return
            }
            retryableFailures.removeValue(forKey: path)
            let previousBytes = progress.uploadedSize
            let previousCount = progress.pendingFiles.count
            // A status refresh without a completed upload must not reset metadata progress.
            if let size, isUploaded || percent > 0 {
                progress.update(path: path, size: size, percent: percent, isUploaded: isUploaded)
            }
            if progress.uploadedSize > previousBytes || progress.pendingFiles.count < previousCount {
                lastProgressTime = ProcessInfo.processInfo.systemUptime
            }
        }
        
    }
    
}
