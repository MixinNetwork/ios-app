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

            let localDir = chatDir.appendingPathComponent(category)
            try FileManager.default.createDirectoryIfNeeded(dir: localDir)

            for content in contents {
                var filename = content
                if filename.hasSuffix(".icloud") {
                    filename = String(filename[filename.index(filename.startIndex, offsetBy: 1)..<filename.index(filename.endIndex, offsetBy: -7)])
                }

                let cloudPath = cloudDir.appendingPathComponent(filename)
                try CloudFile(url: cloudPath).startDownload { (_) in }

                let localPath = localDir.appendingPathComponent(filename)
                try? FileManager.default.removeItem(at: localPath)
                try FileManager.default.copyItem(at: cloudPath, to: localPath)

                restoreFiles += 1
                progress = Float(restoreFiles) / Float(totalFiles)
            }

            AccountUserDefault.shared.removeMedia(category: category)
        }
    }

    private func restoreZipFiles(backupDir: URL, chatDir: URL, category: String) throws -> Bool {
        guard category == MixinFile.ChatDirectory.photos.rawValue || category == MixinFile.ChatDirectory.audios.rawValue else {
            return false
        }

        let zipFile = backupDir.appendingPathComponent("mixin.\(category.lowercased()).zip")
        let cloudFile = CloudFile(url: zipFile)
        let exist = cloudFile.isStoredCloud()
        if exist {
            if !cloudFile.isDownloaded() {
                try cloudFile.startDownload { (_) in }
            }

            let localZip = chatDir.appendingPathComponent("\(category).zip")
            try? FileManager.default.removeItem(at: localZip)
            try FileManager.default.copyItem(at: zipFile, to: localZip)

            let localDir = chatDir.appendingPathComponent(category)

            do {
                try Zip.unzipFile(localZip, destination: localDir, overwrite: true, password: nil, progress: { (_) in
                })

                try? cloudFile.remove()
                AccountUserDefault.shared.removeMedia(category: category)
            } catch {
                #if DEBUG
                print(error)
                #endif
                UIApplication.traceError(error)
            }
        }
        return exist
    }

}
