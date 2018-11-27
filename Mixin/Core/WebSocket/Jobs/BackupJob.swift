import Foundation
import Bugsnag
import Zip

class BackupJob: BaseJob {

    private let immediatelyBackup: Bool

    init(immediatelyBackup: Bool = false) {
        self.immediatelyBackup = immediatelyBackup
        super.init()
    }

    override func getJobId() -> String {
         return "backup"
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
            case .off:
                return
            }
        }

        do {
            try FileManager.default.createDirectoryIfNeeded(dir: backupDir)

            var fileSize: Int64 = 0
            fileSize += try backupDatabase(backupDir: backupDir)
            fileSize += try backupPhotosAndAudios(backupDir: backupDir)
            fileSize += try backupFilesAndVideos(backupDir: backupDir)

            CommonUserDefault.shared.lastBackupTime = Date().timeIntervalSince1970
            CommonUserDefault.shared.lastBackupSize = fileSize
        } catch {
            #if DEBUG
            print(error)
            #endif
            Bugsnag.notifyError(error)
        }
        NotificationCenter.default.postOnMain(name: .BackupDidChange)
    }

    private func backupDatabase(backupDir: URL) throws -> Int64 {
        let databasePath = MixinFile.rootDirectory.appendingPathComponent("mixin.backup.db")
        let iCloudPath = backupDir.appendingPathComponent(databasePath.lastPathComponent)

        try? FileManager.default.removeItem(at: databasePath)

        try MixinDatabase.shared.backup(path: databasePath.path) { (remaining, pagecount) in

        }

        try FileManager.default.replace(from: databasePath, to: iCloudPath)

        try? FileManager.default.removeItem(at: databasePath)

        return FileManager.default.fileSize(iCloudPath.path)
    }

    private func backupPhotosAndAudios(backupDir: URL) throws -> Int64 {
        let categories: [MixinFile.ChatDirectory] = [.photos, .audios]
        var fileSize: Int64 = 0
        for category in categories {
            let dir = MixinFile.url(ofChatDirectory: category, filename: nil)
            let paths = try FileManager.default.contentsOfDirectory(atPath: dir.path).compactMap{ dir.appendingPathComponent($0) }

            guard paths.count > 0 else {
                continue
            }

            let zipPath = try Zip.quickZipFiles(paths, fileName: "mixin.\(category.rawValue.lowercased())")
            try FileManager.default.replace(from: zipPath, to: backupDir.appendingPathComponent(zipPath.lastPathComponent))

            fileSize += FileManager.default.fileSize(zipPath.path)
            try? FileManager.default.removeItem(at: zipPath)
        }
        return fileSize
    }

    private func backupFilesAndVideos(backupDir: URL) throws -> Int64 {
        var categories = [MixinFile.ChatDirectory]()
        var localPaths = Set<String>()
        var cloudPaths = Set<String>()

        if CommonUserDefault.shared.hasBackupFiles {
            categories.append(.files)
            try FileManager.default.createDirectoryIfNeeded(dir: backupDir.appendingPathComponent(MixinFile.ChatDirectory.files.rawValue))
        }
        if CommonUserDefault.shared.hasBackupVideos {
            categories.append(.videos)
            try FileManager.default.createDirectoryIfNeeded(dir: backupDir.appendingPathComponent(MixinFile.ChatDirectory.videos.rawValue))
        }

        for category in categories {
            let localDir = MixinFile.url(ofChatDirectory: category, filename: nil)
            let cloudDir = backupDir.appendingPathComponent(category.rawValue)

            localPaths.formUnion(try FileManager.default.contentsOfDirectory(atPath: localDir.path).compactMap{ "\(category.rawValue)/\($0)" })
            cloudPaths.formUnion(try FileManager.default.contentsOfDirectory(atPath: cloudDir.path).compactMap{ "\(category.rawValue)/\($0)" })
        }

        for path in cloudPaths {
            if !localPaths.contains(path) {
                try FileManager.default.removeItem(at: backupDir.appendingPathComponent(path))
            }
        }

        var fileSize: Int64 = 0
        for path in localPaths {
            let cloudPath = backupDir.appendingPathComponent(path)
            let localPath = MixinFile.rootDirectory.appendingPathComponent("Chat").appendingPathComponent(path)

            if FileManager.default.fileExists(atPath: cloudPath.path) {
                if FileManager.default.fileSize(cloudPath.path) != FileManager.default.fileSize(localPath.path) {
                    _ = try FileManager.default.replaceItemAt(localPath, withItemAt: cloudPath)
                }
            } else {
                try FileManager.default.copyItem(at: localPath, to: cloudPath)
            }
            fileSize += FileManager.default.fileSize(localPath.path)
        }

        return fileSize
    }

}
