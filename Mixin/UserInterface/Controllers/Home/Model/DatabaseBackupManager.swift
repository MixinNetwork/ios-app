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
        let needsBackup: Bool
        if let date = AppGroupUserDefaults.User.lastDatabaseBackupDate {
            needsBackup = -date.timeIntervalSinceNow > TimeInterval.hour * 2
        } else {
            needsBackup = true
        }
        if needsBackup {
            ConcurrentJobQueue.shared.addJob(job: DatabaseBackupJob())
        }
    }
    
}
