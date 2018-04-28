import UIKit

extension UINavigationController {

    func pushViewController(withBackRoot viewController: UIViewController) {
        var viewControllers: [UIViewController] = self.viewControllers
        while viewControllers.count > 0 && !(viewControllers.last is HomeViewController) && !(viewControllers.last is SearchViewController) {
            viewControllers.removeLast()
        }
        viewControllers.append(viewController)
        setViewControllers(viewControllers, animated: true)
    }

    func pushViewController(withBackChat viewController: UIViewController) {
        var viewControllers: [UIViewController] = self.viewControllers
        while (viewControllers.count > 0 && !(viewControllers.last is ConversationViewController)) {
            viewControllers.removeLast()
        }
        viewControllers.append(viewController)
        setViewControllers(viewControllers, animated: true)
    }

    func backToHome() {
        var viewControllers: [UIViewController] = self.viewControllers
        while (viewControllers.count > 0 && !(viewControllers.last is HomeViewController)) {
            viewControllers.removeLast()
        }
        setViewControllers(viewControllers, animated: true)
    }

    func backToChat() {
        var viewControllers: [UIViewController] = self.viewControllers
        while (viewControllers.count > 0 && !(viewControllers.last is ConversationViewController)) {
            viewControllers.removeLast()
        }
        setViewControllers(viewControllers, animated: true)
    }
}

