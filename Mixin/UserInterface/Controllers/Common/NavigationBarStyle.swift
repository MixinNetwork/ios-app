import UIKit

enum NavigationBarStyle {
    
    case normal
    case secondaryBackground
    case hide
    
    static func updateAppearances(
        navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        let style = (viewController as? NavigationBarStyling)?.navigationBarStyle ?? .normal
        switch style {
        case .normal:
            if navigationController.isNavigationBarHidden {
                navigationController.setNavigationBarHidden(false, animated: animated)
            }
            if navigationController.navigationBar.standardAppearance != .general {
                navigationController.navigationBar.standardAppearance = .general
                navigationController.navigationBar.scrollEdgeAppearance = .general
            }
        case .secondaryBackground:
            if navigationController.isNavigationBarHidden {
                navigationController.setNavigationBarHidden(false, animated: animated)
            }
            if navigationController.navigationBar.standardAppearance != .secondaryBackgroundColor {
                navigationController.navigationBar.standardAppearance = .secondaryBackgroundColor
                navigationController.navigationBar.scrollEdgeAppearance = .secondaryBackgroundColor
            }
        case .hide:
            if !navigationController.isNavigationBarHidden {
                navigationController.setNavigationBarHidden(true, animated: animated)
            }
        }
    }
    
}

protocol NavigationBarStyling {
    var navigationBarStyle: NavigationBarStyle { get }
}
