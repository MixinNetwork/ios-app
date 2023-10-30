import Foundation
import MixinServices

class RefreshAccountJob: AsynchronousJob {

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
			case .failure:
				break
			}
			self.finishJob()
		}
		return true
	}

}
