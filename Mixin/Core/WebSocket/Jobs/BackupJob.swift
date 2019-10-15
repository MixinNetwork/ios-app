import Foundation
import Zip
import WCDBSwift

class BackupJob: BaseJob {
    
    static let sharedId = "backup"
    
    private let immediatelyBackup: Bool
    private var totalFileSize: Int64 = 0
    private var backupFileSize: Int64 = 0
    private var needUploadFileSize: Int64 = 0

    private(set) var progress: Float = 0

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
                    try FileManager.default.removeItem(at: backupDir.appendingPathComponent(path))
                }
            }

            let paths: [String] = localPaths.compactMap {
                let localURL = chatDir.appendingPathComponent($0)
                let cloudURL = backupDir.appendingPathComponent($0)

                guard !FileManager.default.fileExists(atPath: cloudURL.path) || FileManager.default.fileSize(cloudURL.path) != FileManager.default.fileSize(localURL.path) else {
                    return nil
                }

                return $0
            }

            totalFileSize = localPaths.map { chatDir.appendingPathComponent($0).fileSize }.reduce(0, +)
            needUploadFileSize = paths.map { chatDir.appendingPathComponent($0).fileSize }.reduce(0, +)
            backupFileSize = 0

            let semaphore = DispatchSemaphore(value: 0)
            let query = NSMetadataQuery()
            query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
            query.valueListAttributes = [NSMetadataUbiquitousItemPercentUploadedKey,
                                         NSMetadataUbiquitousItemIsUploadedKey]

            try? MixinDatabase.shared.database.prepareUpdateSQL(sql: "PRAGMA wal_checkpoint(FULL)").execute()
            let databaseCloudURL = backupDir.appendingPathComponent(MixinFile.backupDatabaseName)
            if !FileManager.default.fileExists(atPath: databaseCloudURL.path) || FileManager.default.fileSize(databaseCloudURL.path) != FileManager.default.fileSize(MixinFile.databaseURL.path) {
                let databaseFileSize = MixinFile.databaseURL.fileSize
                totalFileSize += databaseFileSize
                needUploadFileSize += databaseFileSize
                try uploadToCloud(query: query, semaphore: semaphore, from: MixinFile.databaseURL, destination: databaseCloudURL)
            }

            for path in paths {
                guard !isCancelled else {
                    return
                }
                let localURL = chatDir.appendingPathComponent(path)
                let cloudURL = backupDir.appendingPathComponent(path)
                try uploadToCloud(query: query, semaphore: semaphore, from: localURL, destination: cloudURL)
            }

            progress = 1
            CommonUserDefault.shared.lastBackupTime = Date().timeIntervalSince1970
            CommonUserDefault.shared.lastBackupSize = totalFileSize
        } catch {
            #if DEBUG
            print(error)
            #endif
            UIApplication.traceError(error)
        }
        NotificationCenter.default.postOnMain(name: .BackupDidChange)
    }

    private func uploadToCloud(query: NSMetadataQuery, semaphore: DispatchSemaphore, from: URL, destination: URL) throws {
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.copyItem(at: from, to: tmpFile)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.evictUbiquitousItem(at: destination)
            }
            try FileManager.default.setUbiquitous(true, itemAt: tmpFile, destinationURL: destination)
        } catch {
            if tmpFile.fileExists {
                try? FileManager.default.removeItem(at: tmpFile)
            }
            throw error
        }

        let fileSize = from.fileSize

        query.predicate = NSPredicate(format: "%K LIKE[CD] %@", NSMetadataItemPathKey, destination.path)
        let observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: .main) { [weak self](notification) in
            guard let weakSelf = self else {
                return
            }
            guard !weakSelf.isCancelled else {
                query.stop()
                semaphore.signal()
                return
            }
            guard let metadataItem = (notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem])?.first else {
                return
            }

            for attrName in metadataItem.attributes {
                switch attrName {
                case NSMetadataUbiquitousItemPercentUploadedKey:
                    guard let percent = metadataItem.value(forAttribute: attrName) as? NSNumber else {
                        return
                    }
                    weakSelf.progress = (Float(weakSelf.backupFileSize) + Float(fileSize) * percent.floatValue / 100) / Float(weakSelf.needUploadFileSize)
                case NSMetadataUbiquitousItemIsUploadedKey:
                    guard let status = metadataItem.value(forAttribute: attrName) as? NSNumber, status.boolValue else {
                        return
                    }
                    weakSelf.backupFileSize += fileSize
                    query.stop()
                    semaphore.signal()
                default:
                    break
                }
            }
        }
        DispatchQueue.main.async {
            query.start()
        }
        semaphore.wait()
        NotificationCenter.default.removeObserver(observer)
    }
    
}
