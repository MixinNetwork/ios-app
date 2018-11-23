import Foundation
import Bugsnag
import Zip

class BackupJob: BaseJob {

    private var totalProgress: Float = 0
    private var progress: Float = 0
    private var progressRatio: Float = {
        var progressRatio: Float
        if CommonUserDefault.shared.hasBackupFiles && CommonUserDefault.shared.hasBackupVideos {
            progressRatio = 0.2
        } else if CommonUserDefault.shared.hasBackupFiles || CommonUserDefault.shared.hasBackupVideos {
            progressRatio = 0.25
        } else {
            progressRatio = 0.34
        }
        return progressRatio
    }()

    override func getJobId() -> String {
         return "backup"
    }

    override func run() throws {
        guard FileManager.default.ubiquityIdentityToken != nil else {
            return
        }
        guard let backupDir = FileManager.default.url(forUbiquityContainerIdentifier: "MixinMessenger")?.appendingPathComponent("Backup") else {
            return
        }

        do {
            try FileManager.default.createDirectoryIfNeeded(dir: backupDir)

            var progressRatio: Float
            if CommonUserDefault.shared.hasBackupFiles && CommonUserDefault.shared.hasBackupVideos {
                progressRatio = 0.2
            } else if CommonUserDefault.shared.hasBackupFiles || CommonUserDefault.shared.hasBackupVideos {
                progressRatio = 0.25
            } else {
                progressRatio = 0.34
            }

            try backupDatabase(backupDir: backupDir)
            try backupPhotosAndAudios(backupDir: backupDir, progressRatio: progressRatio)
            try backupFilesAndVideos(backupDir: backupDir, progressRatio: progressRatio)
        } catch {
            Bugsnag.notifyError(error)
            #if DEBUG
            print(error)
            #endif
        }
    }

    private func updateProcess(progress: Float) {
        totalProgress + progress
    }

    private func backupDatabase(backupDir: URL) throws {
        let databasePath = MixinFile.rootDirectory.appendingPathComponent("mixin.backup.db")

        try MixinDatabase.shared.backup(path: databasePath.path) { (remaining, pagecount) in
            let progress = Float(remaining) / Float(pagecount)
//            self.updateProcess(progress: progress)
            NotificationCenter.default.post(name: .AVPlayerItemNewAccessLogEntry, object: progress)
        }

        try FileManager.default.replace(from: databasePath, to: backupDir.appendingPathComponent(databasePath.lastPathComponent))

        try FileManager.default.removeItem(at: databasePath)
    }

    private func backupPhotosAndAudios(backupDir: URL, progressRatio: Float) throws {
        let categories: [MixinFile.ChatDirectory] = [.photos, .audios]
        for category in categories {
            let dir = MixinFile.url(ofChatDirectory: category, filename: nil)
            let paths = try FileManager.default.contentsOfDirectory(atPath: dir.path).compactMap{ dir.appendingPathComponent($0) }

            let zipPath = try Zip.quickZipFiles(paths, fileName: "mixin.\(category.rawValue.lowercased())") { (progress) in
                //print("----------BackupJob...backupPhotosAndAudios...progress:\(progress)")
            }
            try FileManager.default.replace(from: zipPath, to: backupDir.appendingPathComponent(zipPath.lastPathComponent))

            try FileManager.default.removeItem(at: zipPath)
        }
    }

    private func backupFilesAndVideos(backupDir: URL, progressRatio: Float) throws {
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
        }
    }

}
