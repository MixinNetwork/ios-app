import Foundation
import MixinServices

class BackupJobQueue: JobQueue {
    
    static let shared = BackupJobQueue()
    
    var isBackingUp: Bool {
        return backupJob != nil
    }

    var isRestoring: Bool {
        return restoreJob != nil
    }
    
    var backupJob: BackupJob? {
        return findJobById(jodId: BackupJob.jobId) as? BackupJob
    }

    var restoreJob: RestoreJob? {
        return findJobById(jodId: RestoreJob.jobId) as? RestoreJob
    }
    
    init() {
        super.init(maxConcurrentOperationCount: 1)
    }
    
}

