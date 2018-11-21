import Foundation
import Bugsnag

class BackupJob: BaseJob {

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

        print("----------BackupJob......1")

        do {
            if !FileManager.default.fileExists(atPath: backupDir.path) {
                try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true, attributes: nil)
            }

            let backupDatabaseName = "mixin.backup.db"
            let backupDatabase = MixinFile.rootDirectory.appendingPathComponent(backupDatabaseName)
            let iCloudDatabase = backupDir.appendingPathComponent(backupDatabaseName)

            let fileSize = FileManager.default.fileSize(iCloudDatabase.path)
            print("----------BackupJob......2...fileSize:\(fileSize)...\(iCloudDatabase.path)")

//            // backup database
//            try MixinDatabase.shared.backup(path: backupDatabase.path) { (remaining, pagecount) in
//                print("=======BackupJob...remaining:\(remaining)...pagecount:\(pagecount)")
//            }
//
//            // backup files
//            _ = try FileManager.default.replaceItemAt(iCloudDatabase, withItemAt: backupDatabase)
//
//            print("----------BackupJob......finish")
        } catch {
//            Bugsnag.notifyError(error)
            print(error)
        }
    }

}
