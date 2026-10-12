import Foundation
import MixinServices

final class RefreshAccountJob: AsynchronousJob {
    
    override func getJobId() -> String {
        return "refresh-account-\(myUserId)"
    }
    
    override func execute() -> Bool {
        AccountAPI.me { (result) in
            switch result {
            case let .success(account):
                DispatchQueue.global().async {
                    guard !MixinService.isStopProcessMessages else {
                        return
                    }
                    LoginManager.shared.setAccount(account)
                }
            case let .failure(error):
                Logger.tip.warn(category: "RefreshAccountJob", message: "Load account: \(error)")
            }
            self.finishJob()
        }
        return true
    }
    
}
