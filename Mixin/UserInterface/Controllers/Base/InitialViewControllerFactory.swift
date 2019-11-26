import UIKit

func makeInitialViewController() -> UIViewController {
    if AccountUserDefault.shared.hasClockSkew {
        if let viewController = AppDelegate.current.window.rootViewController as? ClockSkewViewController {
            viewController.checkFailed()
            return viewController
        } else {
            while UIApplication.shared.keyWindow?.subviews.last is BottomSheetView {
                UIApplication.shared.keyWindow?.subviews.last?.removeFromSuperview()
            }
            return ClockSkewViewController.instance()
        }
    } else if AccountAPI.shared.account?.full_name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
        return UsernameViewController()
    } else if AccountUserDefault.shared.hasRestoreChat {
        return RestoreViewController.instance()
    } else if DatabaseUserDefault.shared.hasUpgradeDatabase() {
        return DatabaseUpgradeViewController.instance()
    } else if !CryptoUserDefault.shared.isLoaded {
        return SignalLoadingViewController.instance()
    } else {
        return HomeContainerViewController()
    }
}
