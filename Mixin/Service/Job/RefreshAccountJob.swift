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
                Task {
                    do {
                        guard let context = try await TIP.checkCounter(with: account) else {
                            return
                        }
                        await MainActor.run {
                            let intro = TIPIntroViewController(context: context)
                            let navigation = TIPNavigationViewController(intro: intro, destination: nil)
                            UIApplication.homeNavigationController?.present(navigation, animated: true)
                        }
                    } catch {
                        Logger.general.warn(category: "RefreshAccountJob", message: "Check counter: \(error)")
                    }
                }
			case .failure:
				break
			}
			self.finishJob()
		}
		return true
	}

}
