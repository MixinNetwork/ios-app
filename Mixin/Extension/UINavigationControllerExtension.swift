import UIKit

extension UINavigationController {
    
    func pushViewController(withBackRoot viewController: UIViewController) {
        var viewControllers = self.viewControllers
        while viewControllers.count > 0 && !(viewControllers.last is HomeTabBarController) {
            viewControllers.removeLast()
        }
        viewControllers.append(viewController)
        setViewControllers(viewControllers, animated: true)
    }
    
    func pushViewController(withBackChat viewController: UIViewController) {
        var viewControllers = self.viewControllers
        while viewControllers.count > 0 && !(viewControllers.last is HomeTabBarController) && !(viewControllers.last is ConversationViewController) {
            viewControllers.removeLast()
        }
        viewControllers.append(viewController)
        setViewControllers(viewControllers, animated: true)
    }
    
    func backToHome() {
        var viewControllers = self.viewControllers
        while (viewControllers.count > 0 && !(viewControllers.last is HomeTabBarController)) {
            viewControllers.removeLast()
        }
        setViewControllers(viewControllers, animated: true)
    }
    
    func backToChat() {
        var viewControllers = self.viewControllers
        while (viewControllers.count > 0 && !(viewControllers.last is ConversationViewController)) {
            viewControllers.removeLast()
        }
        setViewControllers(viewControllers, animated: true)
    }
    
}
