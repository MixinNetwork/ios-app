import UIKit
import MixinServices

final class CheckTIPCountersJob: AsynchronousJob {
    
    @MainActor
    static var isTIPCounterChecked = false
    
    override func getJobId() -> String {
        return "check-tip-counters-\(myUserId)"
    }
    
    override func execute() -> Bool {
        Task { @MainActor in
            defer {
                finishJob()
            }
            guard !Self.isTIPCounterChecked, !isCancelled else {
                return
            }
            do {
                Logger.tip.debug(category: "CheckTIPCountersJob", message: "Start TIP Counters checking")
                let context = try await TIP.checkCounter()
                guard !isCancelled, LoginManager.shared.isLoggedIn else {
                    return
                }
                guard let context else {
                    Self.isTIPCounterChecked = true
                    return
                }
                let intro = TIPIntroViewController(context: context)
                let navigation = TIPNavigationController(intro: intro)
                UIApplication.shared.homeContainerViewController?.presentOnTopMostPresentedController(navigation, animated: true)
            } catch {
                Logger.tip.warn(category: "CheckTIPCountersJob", message: "Check counter: \(error)")
            }
        }
        return true
    }
    
}
