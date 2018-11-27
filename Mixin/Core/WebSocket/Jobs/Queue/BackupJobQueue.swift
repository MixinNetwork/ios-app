import Foundation
import UIKit

class BackupJobQueue: JobQueue {

    static let shared = BackupJobQueue()

    init() {
        super.init(maxConcurrentOperationCount: 1)
    }

    func isBackuping() -> Bool {
        return isExistJob(jodId: "backup")
    }

}

