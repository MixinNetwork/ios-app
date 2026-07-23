import UIKit
import AVFoundation
import MixinServices

final class HomeNavigationController: GeneralAppearanceNavigationController {
    
    private let interactivePopOutRecognizer = UIScreenEdgePanGestureRecognizer()
    
    private var interactivePopOutTransition: UIPercentDrivenInteractiveTransition?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.interactivePopGestureRecognizer?.isEnabled = true
        self.interactivePopGestureRecognizer?.delegate = self
        interactivePopOutRecognizer.edges = .left
        interactivePopOutRecognizer.addTarget(self, action: #selector(popOutInteractively(_:)))
        interactivePopOutRecognizer.delegate = self
        view.addGestureRecognizer(interactivePopOutRecognizer)
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
    
    func pushWebViewController(context: MixinWebContext) {
        let web = MixinWebViewController(context: context)
        pushViewController(web, animated: true)
    }
    
    func presentReferralPage() {
        presentAppPage(appID: BotUserID.rewards)
    }
    
    func presentCashPage() {
        presentAppPage(appID: BotUserID.mixinCash)
    }
    
    func presentAppPage(appID: String) {
        if let app = AppDAO.shared.getApp(appId: appID) {
            pushWebViewController(context: .init(conversationId: "", app: app))
            let updateUser = RefreshUserJob(userIds: [appID])
            ConcurrentJobQueue.shared.addJob(job: updateUser)
            return
        }
        
        let hud = Hud()
        hud.show(style: .busy, text: "", on: view)
        UserAPI.showUser(userId: appID) { [weak self] result in
            switch result {
            case .success(let response):
                DispatchQueue.global().async {
                    UserDAO.shared.updateUsers(users: [response])
                }
                hud.hide()
                if let app = response.app {
                    self?.pushWebViewController(context: .init(conversationId: "", app: app))
                }
            case .failure(let error):
                hud.set(style: .error, text: error.localizedDescription)
                hud.scheduleAutoHidden()
            }
        }
    }
    
    @objc private func popOutInteractively(_ gesture: UIScreenEdgePanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let decisionDistance = view.bounds.width / 4
        let progress = max(0, min(1, translation.x / decisionDistance))
        switch gesture.state {
        case .began:
            interactivePopOutTransition = UIPercentDrivenInteractiveTransition()
            popViewController(animated: true)
        case .changed:
            interactivePopOutTransition?.update(progress * 0.5)
            if translation.x > decisionDistance {
                gesture.isEnabled = false
                gesture.isEnabled = true
            }
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: view).x
            if velocity >= 0 && (progress > 0.3 || velocity > 300) {
                interactivePopOutTransition?.finish()
            } else {
                interactivePopOutTransition?.cancel()
            }
            interactivePopOutTransition = nil
        default:
            interactivePopOutTransition?.cancel()
            interactivePopOutTransition = nil
        }
    }
    
}

extension HomeNavigationController: UINavigationControllerDelegate {
    
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
    
    func navigationController(
        _ navigationController: UINavigationController,
        interactionControllerFor animationController: any UIViewControllerAnimatedTransitioning
    ) -> (any UIViewControllerInteractiveTransitioning)? {
        interactivePopOutTransition
    }
    
    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        switch operation {
        case .push where toVC is PopupNavigationAnimating:
            PopInNavigationAnimator()
        case .pop where fromVC is PopupNavigationAnimating:
            PopOutNavigationAnimator()
        default:
            nil
        }
    }
    
}

extension HomeNavigationController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        switch gestureRecognizer {
        case interactivePopGestureRecognizer:
            guard viewControllers.count > 1 else {
                return false
            }
            if let vc = viewControllers.last {
                if let vc = vc as? PopupNavigationAnimating, vc.interactivePopOut {
                    return false
                } else {
                    return !(vc is QRCodeScannerViewController)
                }
            } else {
                return true
            }
        case interactivePopOutRecognizer:
            guard viewControllers.count > 1 else {
                return false
            }
            if let vc = viewControllers.last, let vc = vc as? PopupNavigationAnimating {
                return vc.interactivePopOut
            } else {
                return false
            }
        default:
            return true
        }
    }
    
}
