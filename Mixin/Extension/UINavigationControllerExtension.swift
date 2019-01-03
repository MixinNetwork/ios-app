import UIKit

extension UINavigationController {

    func pushViewController(withBackRoot viewController: UIViewController) {
        var viewControllers: [UIViewController] = self.viewControllers
        while viewControllers.count > 0 && !(viewControllers.last is HomeViewController) {
            viewControllers.removeLast()
        }
        viewControllers.append(viewController)
        setViewControllers(viewControllers, animated: true)
    }

    func pushViewController(withBackChat viewController: UIViewController) {
        var viewControllers: [UIViewController] = self.viewControllers
        while viewControllers.count > 0 && !(viewControllers.last is HomeViewController) && !(viewControllers.last is ConversationViewController) {
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
    
    func popToConversation(animated: Bool) {
        guard let chat = viewControllers.first(where: { $0 is ConversationViewController }) else {
            return
        }
        popToViewController(chat, animated: animated)
    }
    
}

