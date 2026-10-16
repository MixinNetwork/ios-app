import UIKit

extension UINavigationController {
    
    func pushViewController(afterRoot viewController: UIViewController) {
        var viewControllers = Array(viewControllers.prefix(1))
        viewControllers.append(viewController)
        setViewControllers(viewControllers, animated: true)
    }
    
    func pushViewController(replacingCurrent viewController: UIViewController, animated: Bool) {
        var viewControllers = self.viewControllers
        viewControllers.removeLast()
        viewControllers.append(viewController)
        setViewControllers(viewControllers, animated: animated)
    }
    
}
