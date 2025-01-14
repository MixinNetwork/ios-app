import UIKit
import AVFoundation
import DeviceCheck
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
            DCDevice.current.generateToken { (data, error) in
                guard let token = data?.base64EncodedString() else {
                    return
                }
                guard LoginManager.shared.isLoggedIn else {
                    return
                }
                AccountAPI.updateSession(deviceCheckToken: token, completion: nil)
            }
            Logger.general.info(category: "HomeNavigationController", message: "View did load with app state: \(UIApplication.shared.applicationStateString)")
            if UIApplication.shared.applicationState == .active {
                WebSocketService.shared.connect(firstConnect: true)
                ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob(request: .allAssets))
                ConcurrentJobQueue.shared.addJob(job: RefreshAllTokensJob())
            }
        }
    }
    
    func pushCameraViewController(asQRCodeScanner: Bool) {
        let camera = CameraViewController.instance()
        camera.asQrCodeScanner = asQRCodeScanner
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            pushViewController(camera, animated: true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { [weak self] (granted) in
                guard granted else {
                    return
                }
                DispatchQueue.main.async {
                    self?.pushViewController(camera, animated: true)
                }
            })
        case .denied, .restricted:
            alertSettings(R.string.localizable.permission_denied_camera_hint())
        @unknown default:
            alertSettings(R.string.localizable.permission_denied_camera_hint())
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
            return !(vc is CameraViewController)
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
