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

                let contents = try FileManager.default.contentsOfDirectory(atPath: cloudDir.path)
                guard contents.count > 0 else {
                    continue
                }

                for content in contents {
                    var filename = content
                    if filename.hasSuffix(".icloud") {
                        filename = String(filename[filename.index(filename.startIndex, offsetBy: 1)..<filename.index(filename.endIndex, offsetBy: -7)])
                    }
                    try downloadFromCloud(url: cloudDir.appendingPathComponent(filename))
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
    
    private func downloadFromCloud(url: URL) throws {
        guard url.cloudExist() else {
            return
        }
        if try url.cloudDownloaded() {
            return
        }

        try FileManager.default.startDownloadingUbiquitousItem(at: url)

        repeat {
            Thread.sleep(forTimeInterval: 1)

            if try url.cloudDownloaded() {
                return
            } else if FileManager.default.fileExists(atPath: url.path) && FileManager.default.fileSize(url.path) > 0 {
                return
            }
        } while true
    }

}
