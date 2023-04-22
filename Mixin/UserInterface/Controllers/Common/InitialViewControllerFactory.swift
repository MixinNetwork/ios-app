import UIKit
import MixinServices

func makeInitialViewController(isUsernameJustInitialized: Bool = false) -> UIViewController {
    if AppGroupUserDefaults.User.isDatabaseCorrupted {
        return DatabaseRepairViewController.instance()
    } else if AppGroupUserDefaults.Account.isClockSkewed {
        if let viewController = AppDelegate.current.mainWindow.rootViewController as? ClockSkewViewController {
            viewController.checkFailed()
            return viewController
        } else {
            while UIApplication.shared.keyWindow?.subviews.last is BottomSheetView {
                UIApplication.shared.keyWindow?.subviews.last?.removeFromSuperview()
            }
            return ClockSkewViewController.instance()
        }
    } else if LoginManager.shared.account?.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
        return UsernameViewController()
    } else if AppGroupUserDefaults.Account.canRestoreChat {
        return RestoreViewController.instance(isUsernameJustInitialized: isUsernameJustInitialized)
    } else if DatabaseUpgradeViewController.needsUpgrade {
        return DatabaseUpgradeViewController.instance(isUsernameJustInitialized: isUsernameJustInitialized)
    } else if !AppGroupUserDefaults.Crypto.isPrekeyLoaded || !AppGroupUserDefaults.Crypto.isSessionSynchronized || !AppGroupUserDefaults.User.isCircleSynchronized {
        return SignalLoadingViewController.instance(isUsernameJustInitialized: isUsernameJustInitialized)
    } else {
        return HomeContainerViewController()
    }
}
