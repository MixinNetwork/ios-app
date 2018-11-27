import UIKit

func makeInitialViewController() -> UIViewController {
    if AccountUserDefault.shared.hasRestoreChat {
        return RestoreViewController.instance()
    } else if !CryptoUserDefault.shared.isLoaded {
        return SignalLoadingViewController.instance()
    } else {
        let viewControllers: [UIViewController]
        if AccountUserDefault.shared.hasClockSkew {
            if let nav = AppDelegate.current.window?.rootViewController as? MixinNavigationController, let viewController = nav.viewControllers.last as? ClockSkewViewController {
                viewController.checkFailed()
                return nav
            } else {
                while UIApplication.shared.keyWindow?.subviews.last is BottomSheetView {
                    UIApplication.shared.keyWindow?.subviews.last?.removeFromSuperview()
                }
                viewControllers = [ClockSkewViewController.instance()]
            }
        } else if CommonUserDefault.shared.hasConversation {
            viewControllers = [HomeViewController.instance()]
        } else {
            if AccountAPI.shared.account?.has_pin ?? false {
                viewControllers = [HomeViewController.instance(),
                                   WalletViewController.instance()]
            } else {
                viewControllers = [HomeViewController.instance(),
                                   WalletPasswordViewController.instance(walletPasswordType: .initPinStep1)]
            }
        }
        let navigationController = MixinNavigationController.instance()
        navigationController.setViewControllers(viewControllers, animated: false)
        return navigationController
    }
}
