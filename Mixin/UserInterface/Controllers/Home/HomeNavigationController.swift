import UIKit
import Bugsnag
import DeviceCheck
import MixinServices

class HomeNavigationController: UINavigationController {
    
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
        return visibleViewController?.children
            .compactMap({ $0 as? WebViewController })
            .filter({ !$0.isBeingDismissedAsChild })
            .last
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.interactivePopGestureRecognizer?.isEnabled = true
        self.interactivePopGestureRecognizer?.delegate = self
        self.isNavigationBarHidden = true
        self.delegate = self
        if AppGroupUserDefaults.Crypto.isPrekeyLoaded && AppGroupUserDefaults.Crypto.isSessionSynchronized && !AppGroupUserDefaults.Account.isClockSkewed {
            MixinService.callMessageCoordinator = CallManager.shared
            WebSocketService.shared.connect()
            if LoginManager.shared.isLoggedIn {
                Reporter.registerUserInformation()
            }
            checkDevice()
            ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob())
        }
    }
    
}

extension HomeNavigationController: UINavigationControllerDelegate {
    
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if operation == .push {
            var targetVC = toVC
            if toVC is ContainerViewController {
                targetVC = (toVC as! ContainerViewController).viewController
            }
            if let targetVC = targetVC as? MixinNavigationAnimating {
                switch targetVC.pushAnimation {
                case .push:
                    return nil
                case .present:
                    presentFromBottomAnimator.operation = operation
                    return presentFromBottomAnimator
                }
            }
        } else if operation == .pop {
            var targetVC = fromVC
            if fromVC is ContainerViewController {
                targetVC = (fromVC as! ContainerViewController).viewController
            }
            if let targetVC = targetVC as? MixinNavigationAnimating {
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
            return !(vc is CameraViewController)
        } else {
            return true
        }
    }
    
}

extension HomeNavigationController {
    
    private func checkDevice() {
        guard LoginManager.shared.isLoggedIn else {
            return
        }
        DCDevice.current.generateToken { (data, error) in
            guard let token = data?.base64EncodedString() else {
                return
            }

            AccountAPI.shared.updateSession(deviceCheckToken: token)
        }
    }
    
}
