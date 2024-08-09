import UIKit
import AVFoundation
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
        return viewControllers.last?.children
            .compactMap({ $0 as? WebViewController })
            .filter({ !$0.isBeingDismissedAsChild })
            .last
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 15.0, *) {
            let backIndicatorImage = R.image.ic_search_back()
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = R.color.background_secondary()
            appearance.shadowColor = nil
            appearance.shadowImage = nil
            appearance.setBackIndicatorImage(backIndicatorImage, transitionMaskImage: backIndicatorImage)
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
        } else {
            updateNavigationBar()
        }
        self.interactivePopGestureRecognizer?.isEnabled = true
        self.interactivePopGestureRecognizer?.delegate = self
        self.isNavigationBarHidden = true
        self.delegate = self
        if AppGroupUserDefaults.Crypto.isPrekeyLoaded && AppGroupUserDefaults.Crypto.isSessionSynchronized && !AppGroupUserDefaults.Account.isClockSkewed && LoginManager.shared.isLoggedIn {
            reporter.registerUserInformation()
            checkDevice()
            Logger.general.info(category: "HomeNavigationController", message: "View did load with app state: \(UIApplication.shared.applicationStateString)")
            if UIApplication.shared.applicationState == .active {
                WebSocketService.shared.connect(firstConnect: true)
                ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob(request: .allAssets))
                ConcurrentJobQueue.shared.addJob(job: RefreshAllTokensJob())
            }
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            updateNavigationBar()
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

            AccountAPI.updateSession(deviceCheckToken: token)
        }
    }
    
    private func updateNavigationBar() {
        guard #unavailable(iOS 15.0) else {
            return
        }
        let backIndicatorImage = R.image.ic_search_back()
        let image = R.color.background()!.image
        navigationBar.setBackgroundImage(image, for: .default)
        navigationBar.shadowImage = image
        navigationBar.backIndicatorImage = backIndicatorImage
        navigationBar.backIndicatorTransitionMaskImage = backIndicatorImage
    }
    
}
