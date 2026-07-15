import UIKit

protocol NavigationBarStyling {
    var navigationBarStyle: NavigationBarStyle { get }
}

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

extension NavigationBarStyle {
    
    final class AppearanceUpdater: NSObject, UINavigationControllerDelegate {
        
        func navigationController(
            _ navigationController: UINavigationController,
            willShow viewController: UIViewController,
            animated: Bool
        ) {
            NavigationBarStyle.updateAppearances(
                navigationController: navigationController,
                willShow: viewController,
                animated: animated
            )
        }
        
    }
    
}
