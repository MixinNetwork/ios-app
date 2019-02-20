import Foundation
import UIKit

class BackupJobQueue: JobQueue {
    
    static let shared = BackupJobQueue()
    
    var isBackingUp: Bool {
        return backupJob != nil
    }
    
    var backupJob: BackupJob? {
        return findJobById(jodId: BackupJob.sharedId) as? BackupJob
    }
    
    init() {
        super.init(maxConcurrentOperationCount: 1)
    }
    
}

