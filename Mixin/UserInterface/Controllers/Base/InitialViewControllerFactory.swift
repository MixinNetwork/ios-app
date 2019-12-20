import UIKit

func makeInitialViewController() -> UIViewController {
    if AppGroupUserDefaults.Account.isClockSkewed {
        if let viewController = AppDelegate.current.window.rootViewController as? ClockSkewViewController {
            viewController.checkFailed()
            return viewController
        } else {
            while UIApplication.shared.keyWindow?.subviews.last is BottomSheetView {
                UIApplication.shared.keyWindow?.subviews.last?.removeFromSuperview()
            }
            return ClockSkewViewController.instance()
        }
    } else if LoginManager.shared.account?.full_name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
        return UsernameViewController()
    } else if AppGroupUserDefaults.Account.canRestoreChat {
        return RestoreViewController.instance()
    } else if AppGroupUserDefaults.User.needsUpgradeInMainApp {
        return DatabaseUpgradeViewController.instance()
    } else if !AppGroupUserDefaults.Crypto.isPrekeyLoaded || !AppGroupUserDefaults.Crypto.isSessionSynchronized {
        return SignalLoadingViewController.instance()
    } else {
        return HomeContainerViewController()
    }
}
