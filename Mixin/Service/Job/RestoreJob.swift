import Foundation
import Zip
import MixinServices

class RestoreJob: CloudJob {
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.restore")
    
    override class var jobId: String {
        "restore"
    }
    
    override func execute() -> Bool {
        guard FileManager.default.ubiquityIdentityToken != nil else {
            return false
        }
        guard let backupUrl = backupUrl else {
            return false
        }
        guard prepare(backupUrl: backupUrl) else {
            return false
        }
        guard pendingFiles.count > 0 else {
            restoreFinished()
            return true
        }
        guard isContinueProcessing else {
            return false
        }
        setupQuery(backupUrl: backupUrl)
        startQuery()
        queue.async(execute: downloadFiles)
        return true
    }
    
    override func setupQuery(backupUrl: URL) {
        super.setupQuery(backupUrl: backupUrl)
        query.valueListAttributes = [NSMetadataUbiquitousItemPercentDownloadedKey,
                                     NSMetadataUbiquitousItemDownloadingErrorKey,
                                     NSMetadataUbiquitousItemDownloadingStatusKey]
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
                    let fileName = item.value(forAttribute: NSMetadataItemFSNameKey) as? String,
                    let file = self.processingFiles[fileName] as? File
                else {
                    continue
                }
                let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
                let isDownloaded = status == NSMetadataUbiquitousItemDownloadingStatusCurrent
                if isDownloaded {
                    self.processingFiles.removeValue(forKey: fileName)
                    self.processedFileSize += file.size
                    self.restore(file)
                } else {
                    let percent = (item.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? NSNumber)?.floatValue ?? 0
                    self.processingFiles[fileName]?.processedSize = Int64(Float(file.size) * percent / 100)
                }
                if let error = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingErrorKey) as? NSError {
                    Logger.general.error(category: "RestoreJob", message: "Download item at \(file.srcURL) failed, error: \(error)")
                }
            }
        }
    }
    
}

extension RestoreJob {
    
    private func prepare(backupUrl: URL) -> Bool {
        do {
            func process(cloudURL: URL, localURL: URL, category: AttachmentContainer.Category, isZipFile: Bool) {
                let fileSize = cloudURL.fileSize
                let downloadedSize: Int64 = cloudURL.isDownloaded ? fileSize : 0
                let file = File(srcURL: cloudURL, dstURL: localURL, size: fileSize, processedSize: downloadedSize, isZipFile: isZipFile, category: category)
                pendingFiles[file.name] = file
                totalFileSize += fileSize
            }
            let categories: [AttachmentContainer.Category] = [.photos, .audios, .files, .videos]
            for category in categories {
                try FileManager.default.createDirectory(at: AttachmentContainer.url(for: category, filename: nil), withIntermediateDirectories: true, attributes: nil)
                
                if category == .photos || category == .audios {
                    let name = category == .photos ? "mixin.photos.zip" : "mixin.audios.zip"
                    if backupUrl.appendingPathComponent(name).isStoredCloud {
                        let cloudURL = backupUrl.appendingPathComponent(name)
                        let localURL = AttachmentContainer.url.appendingPathComponent(name)
                        process(cloudURL: cloudURL, localURL: localURL, category: category, isZipFile: true)
                    }
                }
                
                let cloudDir = backupUrl.appendingPathComponent(category.pathComponent)
                guard FileManager.default.directoryExists(atPath: cloudDir.path) else {
                    Logger.general.info(category: "RestoreJob", message: "Directory not exists at: \(cloudDir.path)")
                    continue
                }
                let contents = try FileManager.default.contentsOfDirectory(atPath: cloudDir.path)
                guard contents.count > 0 else {
                    continue
                }
                let localDir = AttachmentContainer.url.appendingPathComponent(category.pathComponent)
                for content in contents {
                    let name: String
                    if content.hasSuffix(".icloud") {
                        name = String(content[content.index(content.startIndex, offsetBy: 1)..<content.index(content.endIndex, offsetBy: -7)])
                    } else {
                        name = content
                    }
                    let cloudURL = cloudDir.appendingPathComponent(name)
                    let localURL = localDir.appendingPathComponent(name)
                    process(cloudURL: cloudURL, localURL: localURL, category: category, isZipFile: false)
                }
            }
            return true
        } catch {
            Logger.general.error(category: "RestoreJob", message: "Prepare failed: \(error)")
            return false
        }
    }
    
    private func downloadFiles() {
        guard let files = pendingFiles.values as? [File] else {
            return
        }
        for file in files {
            pendingFiles.removeValue(forKey: file.name)
            if file.isProcessingCompleted {
                restore(file)
            } else {
                do {
                    try FileManager.default.startDownloadingUbiquitousItem(at: file.srcURL)
                    processingFiles[file.name] = file
                } catch {
                    Logger.general.error(category: "RestoreJob", message: "Failed to download item at: \(file.srcURL.path), error: \(error)")
                    reporter.report(error: error)
                }
            }
        }
    }
    
    private func restore(_ file: File) {
        do {
            let cloudURL = file.srcURL
            let localURL = file.dstURL
            if FileManager.default.fileExists(atPath: localURL.path) {
                if FileManager.default.fileSize(cloudURL.path) != FileManager.default.fileSize(localURL.path) {
                    try? FileManager.default.removeItem(at: localURL)
                    try FileManager.default.copyItem(at: cloudURL, to: localURL)
                }
            } else {
                try FileManager.default.copyItem(at: cloudURL, to: localURL)
            }
            if file.isZipFile {
                let localDir = AttachmentContainer.url.appendingPathComponent(file.category.pathComponent)
                try Zip.unzipFile(localURL, destination: localDir, overwrite: true, password: nil)
                try FileManager.default.removeItem(at: localURL)
            }
        } catch {
            Logger.general.error(category: "RestoreJob", message: "Failed to restore file: \(file.srcURL), error: \(error)")
            reporter.report(error: error)
        }
        if pendingFiles.count == 0 && processingFiles.count == 0 {
            restoreFinished()
        }
    }
    
    private func restoreFinished() {
        stopQuery()
        AppGroupUserDefaults.Account.canRestoreMedia = false
        NotificationCenter.default.post(onMainThread: BackupJob.backupDidChangeNotification, object: self)
        finishJob()
    }
    
}

extension RestoreJob {
    
    struct File: CloudJobFile {
        var srcURL: URL
        var dstURL: URL
        var size: Int64
        var processedSize: Int64
        var isZipFile: Bool
        var category: AttachmentContainer.Category
    }
    
}
