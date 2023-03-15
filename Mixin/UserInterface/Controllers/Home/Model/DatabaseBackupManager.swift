import Foundation
import MixinServices

class DatabaseBackupManager: NSObject {
    
    static let shared = DatabaseBackupManager()
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(backupIfNeeded), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc func backupIfNeeded() {
        guard LoginManager.shared.isLoggedIn else {
            return
        }
        let lastDatabaseBackupDate = AppGroupUserDefaults.User.lastDatabaseBackupDate
        if lastDatabaseBackupDate == nil || -lastDatabaseBackupDate!.timeIntervalSinceNow > TimeInterval.hour * 2 {
            ConcurrentJobQueue.shared.addJob(job: DatabaseBackupJob())
        }
    }
    
}
