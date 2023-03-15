import Foundation
import MixinServices
import GRDB

class DatabaseBackupJob: AsynchronousJob {
    
    override func getJobId() -> String {
        "database-backup"
    }
    
    override func execute() -> Bool {
        do {
            try UserDatabase.current.writeWithoutTransaction { _ in
                try DatabaseFile.removeIfExists(.temp)
                try DatabaseFile.copy(at: .original, to: .temp)
            }
            let dbQueue = try DatabaseQueue(path: DatabaseFile.temp.db.path)
            try dbQueue.write { db in
                try db.execute(sql: "PRAGMA integrity_check")
            }
            try DatabaseFile.removeIfExists(.backup)
            try DatabaseFile.copy(at: .temp, to: .backup)
            try DatabaseFile.removeIfExists(.temp)
            AppGroupUserDefaults.User.lastDatabaseBackupDate = Date()
            finishJob()
        } catch {
            Logger.general.error(category: "BackupDatabaseJob", message: "Backup database failed: \(error)")
            reporter.report(error: error)
        }
        return true
    }
    
}
