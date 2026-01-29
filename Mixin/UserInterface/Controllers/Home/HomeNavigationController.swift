import UIKit
import AVFoundation
import MixinServices

class HomeNavigationController: GeneralAppearanceNavigationController {
    
    private lazy var presentFromBottomAnimator = PresentFromBottomAnimator()
    
    override var childForStatusBarStyle: UIViewController? {
        if let web = activeWebViewController {
            return web
        } else {
            return super.childForStatusBarStyle
        }
    }
    
    override var childForStatusBarHidden: UIViewController? {
        if let web = activeWebViewController {
            return web
        } else {
            return super.childForStatusBarHidden
        }
    }
    
    private var activeWebViewController: WebViewController? {
        return viewControllers.last?.children
            .compactMap({ $0 as? WebViewController })
            .filter({ !$0.isBeingDismissedAsChild })
            .last
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.interactivePopGestureRecognizer?.isEnabled = true
        self.interactivePopGestureRecognizer?.delegate = self
        self.delegate = self
        if AppGroupUserDefaults.Crypto.isPrekeyLoaded,
           AppGroupUserDefaults.Crypto.isSessionSynchronized,
           !AppGroupUserDefaults.isClockSkewed,
           let account = LoginManager.shared.account
        {
            reporter.registerUserInformation(account: account)
            Logger.general.info(category: "HomeNavigationController", message: "View did load with app state: \(UIApplication.shared.applicationStateString)")
            if UIApplication.shared.applicationState == .active {
                WebSocketService.shared.connect(firstConnect: true)
                ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob(request: .allAssets))
                ConcurrentJobQueue.shared.addJob(job: RefreshAllTokensJob())
            }
        }
    }
    
    func pushQRCodeScannerViewController() {
        VideoCaptureDevice.checkAuthorization {
            let scanner = QRCodeScannerViewController()
            self.pushViewController(scanner, animated: true)
        } onDenied: { alert in
            self.present(alert, animated: true)
        }
    }
    
    func pushMarketViewController(_ viewController: MarketViewController, animated: Bool) {
        if let index = viewControllers.firstIndex(where: { $0 is MarketViewController }) {
            var viewControllers = Array(self.viewControllers[..<index])
            viewControllers.append(viewController)
            setViewControllers(viewControllers, animated: animated)
        } else {
            pushViewController(viewController, animated: animated)
        }
    }
    
}

extension HomeNavigationController: UINavigationControllerDelegate {
    
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
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
        
        if let container = UIApplication.homeContainerViewController {
            let webViewControllers = container.children.compactMap { child in
                child as? MixinWebViewController
            }
            for webViewController in webViewControllers {
                webViewController.minimizeWithAnimation()
            }
        }
    }
    
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if operation == .push {
            if let targetVC = toVC as? MixinNavigationAnimating {
                switch targetVC.pushAnimation {
                case .push:
                    return nil
                case .present:
                    presentFromBottomAnimator.operation = operation
                    return presentFromBottomAnimator
                }
            }
        } else if operation == .pop {
            if let targetVC = fromVC as? MixinNavigationAnimating {
                switch targetVC.popAnimation {
                case .pop:
                    return nil
                case .dismiss:
                    presentFromBottomAnimator.operation = operation
                    return presentFromBottomAnimator
                }
            }
        }
        return nil
    }
    
}

extension HomeNavigationController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard viewControllers.count > 1 else {
            return false
        }
        if let vc = viewControllers.last {
            return !(vc is QRCodeScannerViewController)
        } else {
            return true
        }
    }
    
}

extension HomeNavigationController {
    
    enum NavigationBarStyle {
        case normal
        case secondaryBackground
        case hide
    }
    
    protocol NavigationBarStyling {
        var navigationBarStyle: NavigationBarStyle { get }
    }
    
}
