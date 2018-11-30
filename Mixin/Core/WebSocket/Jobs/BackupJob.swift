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
        let localURL = MixinFile.backupDatabase
        let cloudURL = backupDir.appendingPathComponent(localURL.lastPathComponent)

        try? FileManager.default.removeItem(at: localURL)
        try MixinDatabase.shared.backup(path: localURL.path) { (remaining, pagecount) in

        }

        try FileManager.default.saveToCloud(from: localURL, to: cloudURL)
        return FileManager.default.fileSize(cloudURL.path)
    }

    private func backupPhotosAndAudios(backupDir: URL) throws -> Int64 {
        let categories: [MixinFile.ChatDirectory] = [.photos, .audios]
        var fileSize: Int64 = 0
        for category in categories {
            let localDir = MixinFile.url(ofChatDirectory: category, filename: nil)
            let paths = try FileManager.default.contentsOfDirectory(atPath: localDir.path).compactMap{ localDir.appendingPathComponent($0) }

            guard paths.count > 0 else {
                continue
            }

            let localURL = try Zip.quickZipFiles(paths, fileName: "mixin.\(category.rawValue.lowercased())")
            let cloudURL = backupDir.appendingPathComponent(localURL.lastPathComponent)

            try FileManager.default.saveToCloud(from: localURL, to: cloudURL)
            fileSize += FileManager.default.fileSize(cloudURL.path)
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
        } else {
            FileManager.default.removeDirectoryAndChildFiles(backupDir.appendingPathComponent(MixinFile.ChatDirectory.files.rawValue))
        }

        if CommonUserDefault.shared.hasBackupVideos {
            categories.append(.videos)
            try FileManager.default.createDirectoryIfNeeded(dir: backupDir.appendingPathComponent(MixinFile.ChatDirectory.videos.rawValue))
        } else {
            FileManager.default.removeDirectoryAndChildFiles(backupDir.appendingPathComponent(MixinFile.ChatDirectory.videos.rawValue))
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
            let localURL = MixinFile.rootDirectory.appendingPathComponent("Chat").appendingPathComponent(path)
            let cloudURL = backupDir.appendingPathComponent(path)

            if FileManager.default.fileExists(atPath: cloudURL.path) {
                if FileManager.default.fileSize(cloudURL.path) != FileManager.default.fileSize(localURL.path) {
                    try FileManager.default.saveToCloud(from: localURL, to: cloudURL)
                }
            } else {
                try FileManager.default.saveToCloud(from: localURL, to: cloudURL)
            }
            fileSize += FileManager.default.fileSize(cloudURL.path)
        }
        return fileSize
    }

}
