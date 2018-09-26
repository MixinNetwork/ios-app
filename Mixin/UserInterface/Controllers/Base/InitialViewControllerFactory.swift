import UIKit

func makeInitialViewController() -> UIViewController {
    if !CryptoUserDefault.shared.isLoaded {
        return SignalLoadingViewController.instance()
    } else {
        let viewControllers: [UIViewController]
        if CommonUserDefault.shared.hasConversation {
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
