import Foundation
import MixinServices

class CleanUpLargeThumbImageJob: AsynchronousJob {
    
    override func getJobId() -> String {
        return "clean-up-large-thumb-image"
    }
    
    override func execute() -> Bool {
        MessageDAO.shared.cleanUpLargeThumbImage()
        AppGroupUserDefaults.User.hasCleanedUpLargeThumbImage = true
        Logger.general.info(category: "CleanUpLargeQuoteContentJob", message: "Cleaned up large thumb image")
        return true
    }
    
}
