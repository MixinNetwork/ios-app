import Foundation
import Bugsnag
import Zip

class RestoreJob: BaseJob {

    override func getJobId() -> String {
        return "restore"
    }

    override func run() throws {
        guard AccountUserDefault.shared.hasRestoreFilesAndVideos else {
            return
        }
        guard FileManager.default.ubiquityIdentityToken != nil else {
            return
        }
        guard let backupDir = MixinFile.iCloudBackupDirectory else {
            return
        }

        let chatDir = MixinFile.rootDirectory.appendingPathComponent("Chat")
        let categories: [MixinFile.ChatDirectory] = [.files, .videos]

        do {
            for category in categories {
                let cloudDir = backupDir.appendingPathComponent(category.rawValue)

                guard FileManager.default.fileExists(atPath: cloudDir.path) else {
                    continue
                }

                let localDir = chatDir.appendingPathComponent(category.rawValue)
                try FileManager.default.createDirectoryIfNeeded(dir: localDir)

                let names = try FileManager.default.contentsOfDirectory(atPath: cloudDir.path)
                for name in names {
                    let localPath = localDir.appendingPathComponent(name)
                    let cloudPath = cloudDir.appendingPathComponent(name)
                    if FileManager.default.fileExists(atPath: localPath.path) {
                        if FileManager.default.fileSize(cloudPath.path) != FileManager.default.fileSize(localPath.path) {
                            try? FileManager.default.removeItem(at: localPath)
                            try FileManager.default.copyItem(at: cloudPath, to: localPath)
                        }
                    } else {
                        try FileManager.default.copyItem(at: cloudPath, to: localPath)
                    }
                }
            }
            AccountUserDefault.shared.hasRestoreFilesAndVideos = false
        } catch {
            #if DEBUG
            print(error)
            #endif
            Bugsnag.notifyError(error)
        }
    }

    static func isRestoreChat() -> Bool {
        guard FileManager.default.ubiquityIdentityToken != nil else {
            return false
        }
        guard let backupDir = MixinFile.iCloudBackupDirectory, FileManager.default.fileExists(atPath: backupDir.path) else {
            return false
        }

        let databasePath = backupDir.appendingPathComponent(MixinFile.backupDatabase.lastPathComponent).path
        return FileManager.default.fileExists(atPath: databasePath) && FileManager.default.fileSize(databasePath) > 0
    }
}
