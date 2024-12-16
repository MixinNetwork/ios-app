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
                Task {
                    do {
                        guard let context = try await TIP.checkCounter(with: account) else {
                            return
                        }
                        await MainActor.run {
                            let intro = TIPIntroViewController(context: context)
                            let navigation = TIPNavigationController(intro: intro)
                            UIApplication.homeNavigationController?.present(navigation, animated: true)
                        }
                    } catch {
                        Logger.tip.warn(category: "RefreshAccountJob", message: "Check counter: \(error)")
                    }
                }
            case let .failure(error):
                Logger.tip.warn(category: "RefreshAccountJob", message: "Load account: \(error)")
            }
            self.finishJob()
        }
        return true
    }
    
}
