import UIKit

func makeInitialViewController() -> UIViewController {
    if AccountUserDefault.shared.hasClockSkew {
        if let viewController = AppDelegate.current.window?.rootViewController as? ClockSkewViewController {
            viewController.checkFailed()
            return viewController
        } else {
            while UIApplication.shared.keyWindow?.subviews.last is BottomSheetView {
                UIApplication.shared.keyWindow?.subviews.last?.removeFromSuperview()
            }
            return ClockSkewViewController.instance()
        }
    } else if AccountAPI.shared.account?.full_name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
        return R.storyboard.login.username()!
    } else if AccountUserDefault.shared.hasRestoreChat {
        return RestoreViewController.instance()
    } else if !CryptoUserDefault.shared.isLoaded {
        return SignalLoadingViewController.instance()
    } else {
        let navigationController = MixinNavigationController.instance()
        navigationController.setViewControllers([R.storyboard.home.home()!], animated: false)
        return navigationController
    }
}
