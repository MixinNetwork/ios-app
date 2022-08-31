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
                        let status = try await TIP.checkCounter(account.tipCounter)
                        switch status {
                        case .balanced:
                            break
                        case .greaterThanServer(let context), .inconsistency(let context):
                            await MainActor.run {
                                switch context.nodeCounter {
                                case 0:
                                    break
                                case 1:
                                    let intro = TIPIntroViewController(intent: .create, interruption: .confirmed(context))
                                    let navigation = TIPNavigationViewController(intro: intro, destination: nil)
                                    UIApplication.homeNavigationController?.present(navigation, animated: true)
                                default:
                                    let intro = TIPIntroViewController(intent: .change, interruption: .confirmed(context))
                                    let navigation = TIPNavigationViewController(intro: intro, destination: nil)
                                    UIApplication.homeNavigationController?.present(navigation, animated: true)
                                }
                            }
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
