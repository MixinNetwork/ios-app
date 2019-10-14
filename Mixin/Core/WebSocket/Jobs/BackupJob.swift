import Foundation
import Zip
import WCDBSwift

class BackupJob: BaseJob {
    
    static let sharedId = "backup"
    
    private(set) var progress: Float = 0
    
    private let immediatelyBackup: Bool

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

        let chatDir = MixinFile.rootDirectory.appendingPathComponent("Chat")

        var totalFileSize: Int64 = 0
        var backupFileSize: Int64 = 0
        var needUploadFileSize: Int64 = 0

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

            try? MixinDatabase.shared.database.prepareUpdateSQL(sql: "PRAGMA wal_checkpoint(FULL)").execute()


            var localPaths = Set<String>()
            var cloudPaths = Set<String>()

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

            let databaseFileSize = MixinFile.databaseURL.fileSize
            totalFileSize = databaseFileSize
            needUploadFileSize = databaseFileSize
            totalFileSize += localPaths.map { chatDir.appendingPathComponent($0).fileSize }.reduce(0, +)
            needUploadFileSize += paths.map { chatDir.appendingPathComponent($0).fileSize }.reduce(0, +)

            for path in paths {
                let localURL = chatDir.appendingPathComponent(path)
                let cloudURL = backupDir.appendingPathComponent(path)
                let fileSize = localURL.fileSize

                try CloudFile(url: localURL).startUpload(destination: cloudURL) { [weak self](progress) in
                    guard let weakSelf = self, !weakSelf.isCancelled else {
                        return
                    }
                    weakSelf.progress = (Float(backupFileSize) + Float(fileSize) * progress) / Float(needUploadFileSize)
                }
                backupFileSize += fileSize
            }

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
    
}
