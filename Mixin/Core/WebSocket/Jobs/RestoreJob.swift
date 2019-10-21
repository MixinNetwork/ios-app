import Foundation
import Zip

class RestoreJob: BaseJob {

    private let monitorQueue = DispatchQueue(label: "one.mixin.messenger.queue.restore.download")
    private let restoreQueue = DispatchQueue(label: "one.mixin.messenger.queue.restore")
    private var monitors = SafeDictionary<String, DownloadFile>()
    private var isStoppedQuery = false
    private var isContinueRestore: Bool {
        return !isCancelled && NetworkManager.shared.isReachableOnWiFi
    }

    private(set) var preparing = true
    private(set) var progress: Float = 0
    private(set) var downloadTotalSize: Int64 = 0
    private(set) var downloadedSize: Int64 = 0

    static let sharedId = "restore"

    override func getJobId() -> String {
        return RestoreJob.sharedId
    }

    override func run() throws {
        guard AccountUserDefault.shared.hasRestoreMedia else {
            return
        }
        guard FileManager.default.ubiquityIdentityToken != nil else {
            return
        }
        guard let backupDir = MixinFile.iCloudBackupDirectory else {
            return
        }

        FileManager.default.debugDirectory(directory: backupDir, tree: "---")

        let chatDir = MixinFile.rootDirectory.appendingPathComponent("Chat")
        let categories = [ MixinFile.ChatDirectory.photos.rawValue,
                           MixinFile.ChatDirectory.audios.rawValue,
                           MixinFile.ChatDirectory.files.rawValue,
                           MixinFile.ChatDirectory.videos.rawValue ]

        monitors = SafeDictionary<String, DownloadFile>()
        preparing = true
        downloadTotalSize = 0
        downloadedSize = 0
        isStoppedQuery = false

        for category in categories {
            try FileManager.default.createDirectoryIfNeeded(dir: chatDir.appendingPathComponent(category))

            if (category == MixinFile.ChatDirectory.photos.rawValue || category == MixinFile.ChatDirectory.audios.rawValue) && backupDir.appendingPathComponent("mixin.\(category.lowercased()).zip").isStoredCloud {
                let filename = "mixin.\(category.lowercased()).zip"
                monitorURL(cloudURL: backupDir.appendingPathComponent(filename), localURL: chatDir.appendingPathComponent(filename), category: category, isZipFile: true)
            } else {
                let cloudDir = backupDir.appendingPathComponent(category)
                guard FileManager.default.fileExists(atPath: cloudDir.path) else {
                    continue
                }

                let contents = try FileManager.default.contentsOfDirectory(atPath: cloudDir.path)
                guard contents.count > 0 else {
                    continue
                }

                let localDir = chatDir.appendingPathComponent(category)
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

                let monitors = weakSelf.monitors
                for metadataItem in metadataItems {
                    let name = metadataItem.value(forAttribute: NSMetadataItemFSNameKey) as? String
                    let fileSize = (metadataItem.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber)?.int64Value ?? 0
                    let percent = (metadataItem.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? NSNumber)?.floatValue ?? 0
                    let isDownloaded = (metadataItem.value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? NSNumber)?.boolValue ?? false

                    if let error = metadataItem.value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? NSError {
                        UIApplication.traceError(error)
                    }

                    if let fileName = name, fileSize > 0, percent > 0, var monitorFile = monitors[fileName] {
                        monitorFile.downloadedSize = isDownloaded ? fileSize : Int64(Float(fileSize) * percent / 100)
                        monitorFile.isDownloaded = isDownloaded
                        monitors[fileName] = monitorFile
                        if isDownloaded {
                            weakSelf.restoreFromCloud(file: monitorFile, chatDir: chatDir, semaphore: semaphore, query: query)
                        }
                    }
                }
                weakSelf.monitors = monitors
                weakSelf.downloadedSize = monitors.values.map { $0.downloadedSize }.reduce(0, +)
            }
        }

        query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        query.valueListAttributes = [ NSMetadataUbiquitousItemPercentDownloadedKey,
                                      NSMetadataUbiquitousItemIsDownloadingKey,
                                      NSMetadataUbiquitousItemDownloadingErrorKey,
                                      NSMetadataUbiquitousItemDownloadingStatusKey]
        query.predicate = NSPredicate(format: "%K BEGINSWITH[c] %@ && kMDItemContentType != 'public.folder'", NSMetadataItemPathKey, backupDir.path)
        DispatchQueue.main.async {
            query.start()
        }
        preparing = false

        let fileNames = [String](monitors.keys)
        for fileName in fileNames {
            guard let file = monitors[fileName], isContinueRestore else {
                continue
            }
            if file.cloudURL.isDownloaded {
                restoreFromCloud(file: file, chatDir: chatDir, semaphore: semaphore, query: query)
            } else if !file.cloudURL.isDownloading {
                do {
                    try FileManager.default.startDownloadingUbiquitousItem(at: file.cloudURL)
                } catch {
                    monitors.removeValue(forKey: fileName)
                    UIApplication.traceError(error)
                }
            }
        }

        if monitors.count == 0 || !isContinueRestore {
            DispatchQueue.main.async {
                query.stop()
            }
        } else {
            semaphore.wait()
        }
        NotificationCenter.default.removeObserver(observer)
        NotificationCenter.default.postOnMain(name: .BackupDidChange)
    }

    func monitorURL(cloudURL: URL, localURL: URL, category: String, isZipFile: Bool = false) {
        if cloudURL.isDownloaded {
            let fileSize = cloudURL.fileSize
            downloadTotalSize += fileSize
            downloadedSize += fileSize
            monitors[cloudURL.lastPathComponent] = DownloadFile(cloudURL: cloudURL, localURL: localURL, category: category, downloadedSize: fileSize, isDownloaded: true, isRestored: false, isZipFile: isZipFile)
        } else {
            monitors[cloudURL.lastPathComponent] = DownloadFile(cloudURL: cloudURL, localURL: localURL, category: category, downloadedSize: 0, isDownloaded: false, isRestored: false, isZipFile: isZipFile)
        }
    }

    private func restoreFromCloud(file: DownloadFile, chatDir: URL, semaphore: DispatchSemaphore, query: NSMetadataQuery) {
        var file = file
        restoreQueue.async { [weak self] in
            guard let weakSelf = self else {
                return
            }
            guard weakSelf.isContinueRestore else {
                weakSelf.stopQuery(query: query, semaphore: semaphore)
                return
            }
            let restoreSuccess = {
                if !file.isRestored {
                    file.isRestored = true
                    weakSelf.monitors[file.cloudURL.lastPathComponent] = file
                }

                if weakSelf.monitors.values.first(where: { !$0.isRestored }) == nil {
                    weakSelf.stopQuery(query: query, semaphore: semaphore)
                }
            }

            if file.isRestored {
                restoreSuccess()
                return
            }

            do {
                if file.isZipFile {
                    let localDir = chatDir.appendingPathComponent(file.category)
                    if FileManager.default.directoryExists(atPath: localDir.path) {
                        let contents = try FileManager.default.contentsOfDirectory(atPath: localDir.path)
                        if contents.count > 0 {
                            restoreSuccess()
                            return
                        }
                    }
                }

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
                    let localDir = chatDir.appendingPathComponent(file.category)
                    try Zip.unzipFile(localURL, destination: localDir, overwrite: true, password: nil)
                    try FileManager.default.removeItem(at: file.localURL)
                }

                restoreSuccess()
            } catch {
                UIApplication.traceError(error)
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
    let category: String
    var downloadedSize: Int64
    var isDownloaded: Bool
    var isRestored: Bool
    var isZipFile: Bool

}
