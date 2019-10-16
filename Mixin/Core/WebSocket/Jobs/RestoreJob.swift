import Foundation
import Zip

class RestoreJob: BaseJob {

    private(set) var progress: Float = 0

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

        let chatDir = MixinFile.rootDirectory.appendingPathComponent("Chat")
        let categories = AccountUserDefault.shared.restoreMedia
        var totalFiles = 0
        var restoreFiles = 0

        for category in categories {
            let cloudDir = backupDir.appendingPathComponent(category)
            guard FileManager.default.fileExists(atPath: cloudDir.path) else {
                continue
            }
            totalFiles += try FileManager.default.contentsOfDirectory(atPath: cloudDir.path).count
        }

        FileManager.default.debugDirectory(directory: backupDir, tree: "---")

        for category in categories {
            guard try !restoreZipFiles(backupDir: backupDir, chatDir: chatDir, category: category) else {
                continue
            }

            let cloudDir = backupDir.appendingPathComponent(category)
            guard FileManager.default.fileExists(atPath: cloudDir.path) else {
                AccountUserDefault.shared.removeMedia(category: category)
                continue
            }

            let contents = try FileManager.default.contentsOfDirectory(atPath: cloudDir.path)
            guard contents.count > 0 else {
                AccountUserDefault.shared.removeMedia(category: category)
                continue
            }

            let semaphore = DispatchSemaphore(value: 0)
            let query = NSMetadataQuery()
            query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
            query.valueListAttributes = [NSMetadataUbiquitousItemPercentDownloadedKey]

            let localDir = chatDir.appendingPathComponent(category)
            try FileManager.default.createDirectoryIfNeeded(dir: localDir)

            for content in contents {
                var filename = content
                if filename.hasSuffix(".icloud") {
                    filename = String(filename[filename.index(filename.startIndex, offsetBy: 1)..<filename.index(filename.endIndex, offsetBy: -7)])
                }

                let cloudURL = cloudDir.appendingPathComponent(filename)
                try downloadFromCloud(query: query, semaphore: semaphore, cloudURL: cloudURL)

                let localURL = localDir.appendingPathComponent(filename)
                if FileManager.default.fileExists(atPath: localURL.path) {
                    if FileManager.default.fileSize(localURL.path) != FileManager.default.fileSize(cloudURL.path) {
                        try? FileManager.default.removeItem(at: localURL)
                        try FileManager.default.copyItem(at: cloudURL, to: localURL)
                    }
                } else {
                    try FileManager.default.copyItem(at: cloudURL, to: localURL)
                }

                restoreFiles += 1
                progress = Float(restoreFiles) / Float(totalFiles)
            }

            AccountUserDefault.shared.removeMedia(category: category)
        }
        NotificationCenter.default.postOnMain(name: .BackupDidChange)
    }

    private func restoreZipFiles(backupDir: URL, chatDir: URL, category: String) throws -> Bool {
        guard category == MixinFile.ChatDirectory.photos.rawValue || category == MixinFile.ChatDirectory.audios.rawValue else {
            return false
        }

        let zipFile = backupDir.appendingPathComponent("mixin.\(category.lowercased()).zip")
        let exist = zipFile.isStoredCloud
        if exist {
            if !zipFile.isDownloaded {
                try zipFile.downloadFromCloud { (_) in }
            }

            let localZip = chatDir.appendingPathComponent("\(category).zip")
            try? FileManager.default.removeItem(at: localZip)
            try FileManager.default.copyItem(at: zipFile, to: localZip)

            let localDir = chatDir.appendingPathComponent(category)

            do {
                try Zip.unzipFile(localZip, destination: localDir, overwrite: true, password: nil, progress: { (_) in
                })

                try FileManager.default.removeItem(at: localZip)
                AccountUserDefault.shared.removeMedia(category: category)
            } catch {
                UIApplication.traceError(error)
            }
        }
        return exist
    }

    private func downloadFromCloud(query: NSMetadataQuery, semaphore: DispatchSemaphore, cloudURL: URL) throws {
        guard !cloudURL.isDownloaded else {
            return
        }
        try FileManager.default.startDownloadingUbiquitousItem(at: cloudURL)

        query.predicate = NSPredicate(format: "%K LIKE[CD] %@", NSMetadataItemPathKey, cloudURL.path)
        let observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: nil, queue: .main) { (notification) in

            guard let metadataItem = (notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem])?.first else {
                return
            }

            if let status = metadataItem.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String {
                guard status == NSMetadataUbiquitousItemDownloadingStatusDownloaded || status == NSMetadataUbiquitousItemDownloadingStatusCurrent else {
                    return
                }
                query.stop()
                semaphore.signal()
            }
        }
        DispatchQueue.main.async {
            query.start()
        }
        semaphore.wait()
        NotificationCenter.default.removeObserver(observer)
    }

}
