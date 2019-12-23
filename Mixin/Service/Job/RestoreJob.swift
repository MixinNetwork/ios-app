import Foundation
import Zip
import MixinServices

class RestoreJob: BaseJob {

    private let monitorQueue = DispatchQueue(label: "one.mixin.messenger.queue.restore.download")
    private let restoreQueue = DispatchQueue(label: "one.mixin.messenger.queue.restore")
    private var monitors = SafeDictionary<String, DownloadFile>()
    private var totalFileSize: Int64 = 0
    private var downloadedSize: Int64 = 0
    private var isStoppedQuery = false
    private var isContinueRestore: Bool {
        return !isCancelled && NetworkManager.shared.isReachableOnWiFi
    }
    private var isRestoredAllFiles: Bool {
        return monitors.values.first(where: { !$0.isRestored }) == nil
    }

    var progress: Float {
        return Float(Float64(downloadedSize) / Float64(totalFileSize))
    }

    static let sharedId = "restore"

    override func getJobId() -> String {
        return RestoreJob.sharedId
    }

    override func run() throws {
        guard AppGroupUserDefaults.Account.canRestoreMedia else {
            return
        }
        guard FileManager.default.ubiquityIdentityToken != nil else {
            return
        }
        guard let backupUrl = backupUrl else {
            return
        }
        
        let categories: [AttachmentContainer.Category] = [.photos, .audios, .files, .videos]
        
        monitors = SafeDictionary<String, DownloadFile>()
        totalFileSize = 0
        downloadedSize = 0
        isStoppedQuery = false

        for category in categories {
            try FileManager.default.createDirectory(at: AttachmentContainer.url(for: category, filename: nil), withIntermediateDirectories: true, attributes: nil)
            
            if category == .photos, backupUrl.appendingPathComponent("mixin.photos.zip").isStoredCloud {
                let filename = "mixin.photos.zip"
                monitorURL(cloudURL: backupUrl.appendingPathComponent(filename),
                           localURL: AttachmentContainer.url.appendingPathComponent(filename),
                           category: category,
                           isZipFile: true)
            }
            if category == .audios, backupUrl.appendingPathComponent("mixin.audios.zip").isStoredCloud {
                let filename = "mixin.audios.zip"
                monitorURL(cloudURL: backupUrl.appendingPathComponent(filename),
                           localURL: AttachmentContainer.url.appendingPathComponent(filename),
                           category: category,
                           isZipFile: true)
            }
            
            let cloudDir = backupUrl.appendingPathComponent(category.pathComponent)
            guard FileManager.default.directoryExists(atPath: cloudDir.path) else {
                continue
            }

            let contents = try FileManager.default.contentsOfDirectory(atPath: cloudDir.path)
            guard contents.count > 0 else {
                continue
            }

            let localDir = AttachmentContainer.url.appendingPathComponent(category.pathComponent)
            for content in contents {
                var filename = content
                if filename.hasSuffix(".icloud") {
                    filename = String(filename[filename.index(filename.startIndex, offsetBy: 1)..<filename.index(filename.endIndex, offsetBy: -7)])
                }
                let cloudURL = cloudDir.appendingPathComponent(filename)
                let localURL = localDir.appendingPathComponent(filename)
                monitorURL(cloudURL: cloudURL, localURL: localURL, category: category)
            }
        }

        guard isContinueRestore else {
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
                guard weakSelf.isContinueRestore else {
                    weakSelf.stopQuery(query: query, semaphore: semaphore)
                    return
                }

                for metadataItem in metadataItems {
                    let name = metadataItem.value(forAttribute: NSMetadataItemFSNameKey) as? String
                    let fileSize = (metadataItem.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber)?.int64Value ?? 0
                    let percent = (metadataItem.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? NSNumber)?.floatValue ?? 0
                    let status = (metadataItem.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String)
                    let isDownloaded = status == NSMetadataUbiquitousItemDownloadingStatusCurrent

                    if let error = metadataItem.value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? NSError {
                        Reporter.report(error: error)
                    }

                    if let fileName = name, fileSize > 0, percent > 0, var monitorFile = weakSelf.monitors[fileName] {
                        monitorFile.downloadedSize = isDownloaded ? fileSize : Int64(Float(fileSize) * percent / 100)
                        monitorFile.isDownloaded = isDownloaded
                        monitorFile.fileSize = fileSize
                        weakSelf.monitors[fileName] = monitorFile
                        if isDownloaded {
                            weakSelf.restoreFromCloud(fileName: fileName, chatDir: AttachmentContainer.url, semaphore: semaphore, query: query)
                        }
                    }
                }

                var totalFileSize: Int64 = 0
                var downloadedSize: Int64 = 0
                weakSelf.monitors.values.forEach({ (monitorFile) in
                    totalFileSize += monitorFile.fileSize
                    downloadedSize += monitorFile.downloadedSize
                })
                weakSelf.totalFileSize = totalFileSize
                weakSelf.downloadedSize = downloadedSize
            }
        }

        query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        query.valueListAttributes = [ NSMetadataUbiquitousItemPercentDownloadedKey,
                                      NSMetadataUbiquitousItemIsDownloadingKey,
                                      NSMetadataUbiquitousItemDownloadingErrorKey,
                                      NSMetadataUbiquitousItemDownloadingStatusKey]
        query.predicate = NSPredicate(format: "%K BEGINSWITH[c] %@ && kMDItemContentType != 'public.folder'", NSMetadataItemPathKey, backupUrl.path)
        DispatchQueue.main.async {
            query.start()
        }

        let fileNames = [String](monitors.keys)
        for fileName in fileNames {
            guard let file = monitors[fileName], isContinueRestore else {
                continue
            }
            if file.cloudURL.isDownloaded {
                restoreFromCloud(fileName: fileName, chatDir: AttachmentContainer.url, semaphore: semaphore, query: query)
            } else {
                do {
                    try FileManager.default.startDownloadingUbiquitousItem(at: file.cloudURL)
                } catch {
                    monitors.removeValue(forKey: fileName)
                    Reporter.report(error: error)
                }
            }
        }

        if monitors.count == 0 || !isContinueRestore || isRestoredAllFiles {
            DispatchQueue.main.async {
                query.stop()
            }
        } else {
            semaphore.wait()
        }

        if isRestoredAllFiles {
            AppGroupUserDefaults.Account.canRestoreMedia = false
        }

        NotificationCenter.default.removeObserver(observer)
        NotificationCenter.default.postOnMain(name: .BackupDidChange)
    }

    func monitorURL(cloudURL: URL, localURL: URL, category: AttachmentContainer.Category, isZipFile: Bool = false) {
        if cloudURL.isDownloaded {
            let fileSize = cloudURL.fileSize
            totalFileSize += fileSize
            downloadedSize += fileSize
            monitors[cloudURL.lastPathComponent] = DownloadFile(cloudURL: cloudURL, localURL: localURL, category: category, downloadedSize: fileSize, fileSize: fileSize, isDownloaded: true, isRestored: false, isZipFile: isZipFile)
        } else {
            monitors[cloudURL.lastPathComponent] = DownloadFile(cloudURL: cloudURL, localURL: localURL, category: category, downloadedSize: 0, fileSize: 0, isDownloaded: false, isRestored: false, isZipFile: isZipFile)
        }
    }

    private func restoreFromCloud(fileName: String, chatDir: URL, semaphore: DispatchSemaphore, query: NSMetadataQuery) {
        restoreQueue.async { [weak self] in
            guard let weakSelf = self else {
                return
            }
            guard !weakSelf.isCancelled else {
                weakSelf.stopQuery(query: query, semaphore: semaphore)
                return
            }
            guard var file = weakSelf.monitors[fileName] else {
                return
            }
            let filename = file.cloudURL.lastPathComponent
            let restoreSuccess = {
                if !file.isRestored {
                    file.isRestored = true
                    weakSelf.monitors[filename] = file
                }

                if weakSelf.isRestoredAllFiles {
                    weakSelf.stopQuery(query: query, semaphore: semaphore)
                }
            }
            let restoreFailed = {
                weakSelf.monitors.removeValue(forKey: filename)
                if weakSelf.isRestoredAllFiles {
                    weakSelf.stopQuery(query: query, semaphore: semaphore)
                }
            }

            if file.isRestored {
                restoreSuccess()
                return
            }

            do {
                let cloudURL = file.cloudURL
                let localURL = file.localURL
                if FileManager.default.fileExists(atPath: localURL.path) {
                    if FileManager.default.fileSize(localURL.path) != FileManager.default.fileSize(cloudURL.path) {
                        try? FileManager.default.removeItem(at: localURL)
                        try FileManager.default.copyItem(at: cloudURL, to: localURL)
                    }
                } else {
                    try FileManager.default.copyItem(at: cloudURL, to: localURL)
                }

                if file.isZipFile {
                    let localDir = chatDir.appendingPathComponent(file.category.pathComponent)
                    try Zip.unzipFile(localURL, destination: localDir, overwrite: true, password: nil)
                    try FileManager.default.removeItem(at: file.localURL)
                }

                restoreSuccess()
            } catch {
                Reporter.report(error: error)
                restoreFailed()
            }
        }
    }

    private func stopQuery(query: NSMetadataQuery, semaphore: DispatchSemaphore) {
        guard !isStoppedQuery else {
            return
        }
        isStoppedQuery = true
        query.stop()
        semaphore.signal()
    }
}

private struct DownloadFile {

    let cloudURL: URL
    let localURL: URL
    let category: AttachmentContainer.Category
    var downloadedSize: Int64
    var fileSize: Int64
    var isDownloaded: Bool
    var isRestored: Bool
    var isZipFile: Bool

}
