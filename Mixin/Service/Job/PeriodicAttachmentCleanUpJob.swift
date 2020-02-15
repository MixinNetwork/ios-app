import UIKit
import MixinServices

class PeriodicAttachmentCleanUpJob: BaseJob {

    override func getJobId() -> String {
       "periodic_attachment_clean_up"
    }

    override func run() throws {
        guard -AppGroupUserDefaults.User.lastAttachmentCleanUpDate.timeIntervalSinceNow >= 86400 * 7 else {
            return
        }
        AttachmentContainer.cleanUpAll()
        AppGroupUserDefaults.User.lastAttachmentCleanUpDate = Date()
    }
}
