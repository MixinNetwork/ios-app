import UIKit
import MixinServices

final class HomeContainerViewController: UIViewController {
    
    let homeTabBarController: HomeTabBarController
    let homeNavigationController: HomeNavigationController
    
    let clipSwitcher = ClipSwitcher()
    let overlaysCoordinator = HomeOverlaysCoordinator()
    
    var pipController: GalleryVideoItemViewController?
    
    lazy var galleryViewController: GalleryViewController = {
        let controller = GalleryViewController()
        controller.delegate = self
        galleryViewControllerIfLoaded = controller
        return controller
    }()
    
    lazy var minimizedCallViewController: MinimizedCallViewController = {
        let controller: MinimizedCallViewController = makeAndAddOverlay()
        minimizedCallViewControllerIfLoaded = controller
        return controller
    }()
    
    lazy var minimizedClipSwitcherViewController: MinimizedClipSwitcherViewController = makeAndAddOverlay()
    lazy var minimizedPlaylistViewController: MinimizedPlaylistViewController = makeAndAddOverlay()
    
    override var childForStatusBarHidden: UIViewController? {
        topMostChild
    }
    
    override var childForStatusBarStyle: UIViewController? {
        topMostChild
    }
    
    override var childForHomeIndicatorAutoHidden: UIViewController? {
        topMostChild
    }
    
    public var topMostChild: UIViewController {
        if let switcher = clipSwitcher.fullscreenSwitcherIfLoaded, switcher.isShowing {
            return switcher
        } else if galleryIsOnTopMost {
            return galleryViewController
        } else {
            return homeNavigationController
        }
    }
    
    private(set) var isShowingGallery = false
    private(set) var galleryViewControllerIfLoaded: GalleryViewController?
    
    private(set) weak var minimizedCallViewControllerIfLoaded: MinimizedCallViewController?
    
    private let sessionReporter = SessionReporter()
    
    private var navigationInteractiveGestureWasEnabled = true
    
    var galleryIsOnTopMost: Bool {
        isShowingGallery && galleryViewController.parent != nil
    }
    
    init(initialTab: HomeTabBarController.ChildID) {
        let homeTabBarController = HomeTabBarController(initialChild: initialTab)
        self.homeTabBarController = homeTabBarController
        self.homeNavigationController = HomeNavigationController(rootViewController: homeTabBarController)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(homeNavigationController)
        view.addSubview(homeNavigationController.view)
        homeNavigationController.view.snp.makeEdgesEqualToSuperview()
        homeNavigationController.didMove(toParent: self)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillEnterForeground(_:)),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        sessionReporter.reportIfOutdated()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if let controller = pipController {
            // TODO: It's hard to arrange overlays in landscape mode, close it as workaround currently
            controller.closeAction()
        }
        let overlays = overlaysCoordinator.visibleOverlays
        overlays.forEach { $0.alpha = 0 }
        coordinator.animate(alongsideTransition: nil) { (context) in
            overlays.forEach { $0.alpha = 1 }
        }
    }
    
    func presentOnTopMostPresentedController(_ viewControllerToPresent: UIViewController, animated: Bool) {
        var topMost: UIViewController = self
        while let next = topMost.presentedViewController, !next.isBeingDismissed {
            topMost = next
        }
        topMost.present(viewControllerToPresent, animated: true)
    }
    
    func presentReferralPage() {
        let appID = BotUserID.referral
        
        if let app = AppDAO.shared.getApp(appId: appID) {
            presentWebViewController(context: .init(conversationId: "", app: app))
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
                    self?.presentWebViewController(context: .init(conversationId: "", app: app))
                }
            case .failure(let error):
                hud.set(style: .error, text: error.localizedDescription)
                hud.scheduleAutoHidden()
            }
        }
    }
    
    func presentWebViewController(context: MixinWebViewController.Context) {
        present(webViewController: .instance(with: context))
    }
    
    func present(webViewController web: MixinWebViewController, completion: (() -> Void)? = nil) {
        AppDelegate.current.mainWindow.endEditing(true)
        
        let topWebViewIndex: Int?
        if let topWebViewController = children.lazy.compactMap({ $0 as? MixinWebViewController }).last {
            topWebViewIndex = view.subviews.lastIndex(of: topWebViewController.view)
        } else {
            topWebViewIndex = nil
        }
        
        web.view.frame = view.bounds
        web.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addChild(web)
        if let topWebViewIndex {
            view.insertSubview(web.view, at: topWebViewIndex + 1)
        } else {
            view.insertSubview(web.view, aboveSubview: homeNavigationController.view)
        }
        didMove(toParent: self)
        
        web.view.center.y = view.bounds.height * 3 / 2
        UIView.animate(withDuration: 0.5, delay: 0, options: .overdampedCurve) {
            web.view.center.y = self.view.bounds.height / 2
        } completion: { _ in
            completion?()
        }
    }
    
    @objc private func applicationWillEnterForeground(_ notification: Notification) {
        if UIApplication.shared.isLandscape, let controller = pipController, controller.isAvPipActive {
            if #available(iOS 16.0, *) {
                if let windowScene = view.window?.windowScene {
                    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
                }
            } else {
                let portrait = Int(UIInterfaceOrientation.portrait.rawValue)
                UIDevice.current.setValue(portrait, forKey: "orientation")
            }
        }
    }
    
}

extension HomeContainerViewController: GalleryViewControllerDelegate {
    
    func galleryViewController(_ viewController: GalleryViewController, cellFor item: GalleryItem) -> GalleryTransitionSource? {
        return chainingDelegate(of: item.conversationId)?.galleryViewController(viewController, cellFor: item)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, willShow item: GalleryItem) {
        removeGalleryFromItsParentIfNeeded()
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        viewController.view.frame = view.bounds
        addChild(viewController)
        if let pipController = pipController {
            view.bringSubviewToFront(pipController.view)
            view.insertSubview(viewController.view, belowSubview: pipController.view)
        } else {
            view.addSubview(viewController.view)
        }
        viewController.didMove(toParent: self)
        isShowingGallery = true
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        chainingDelegate(of: item.conversationId)?.galleryViewController(viewController, willShow: item)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, didShow item: GalleryItem) {
        if let recognizer = homeNavigationController.interactivePopGestureRecognizer {
            navigationInteractiveGestureWasEnabled = recognizer.isEnabled
            recognizer.isEnabled = false
        }
        chainingDelegate(of: item.conversationId)?.galleryViewController(viewController, didShow: item)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, willDismiss item: GalleryItem) {
        chainingDelegate(of: item.conversationId)?.galleryViewController(viewController, willDismiss: item)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, didDismiss item: GalleryItem, relativeOffset: CGFloat?) {
        removeGalleryFromItsParentIfNeeded()
        isShowingGallery = false
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        chainingDelegate(of: item.conversationId)?.galleryViewController(viewController, didDismiss: item, relativeOffset: relativeOffset)
        homeNavigationController.interactivePopGestureRecognizer?.isEnabled = navigationInteractiveGestureWasEnabled
    }
    
    func galleryViewController(_ viewController: GalleryViewController, didCancelDismissalFor item: GalleryItem) {
        chainingDelegate(of: item.conversationId)?.galleryViewController(viewController, didCancelDismissalFor: item)
    }
    
}

extension HomeContainerViewController {
    
    private func makeAndAddOverlay<Controller: HomeOverlayViewController>() -> Controller {
        let controller = Controller()
        controller.view.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin]
        addChild(controller)
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        controller.updateViewSize()
        controller.panningController.placeViewNextToLastOverlayOrTopRight()
        overlaysCoordinator.register(overlay: controller.view)
        return controller
    }
    
    private func chainingDelegate(of conversationId: String) -> GalleryViewControllerDelegate? {
        let sharedMedia = homeNavigationController.viewControllers
            .compactMap({ $0 as? SharedMediaViewController })
            .first(where: { $0.conversationId == conversationId })?
            .children
            .compactMap({ $0 as? SharedMediaMediaViewController })
            .first
        if let delegate = sharedMedia {
            return delegate
        }
        let conversation = homeNavigationController.viewControllers
            .compactMap({ $0 as? ConversationViewController })
            .first(where: { $0.conversationId == conversationId })
        if let conversation = conversation {
            let isShowingStaticMessages = conversation.children.contains { child in
                child is TranscriptPreviewViewController || child is PinMessagesPreviewViewController
            }
            if isShowingStaticMessages {
                return nil
            } else {
                return conversation
            }
        } else {
            return nil
        }
    }
    
    private func removeGalleryFromItsParentIfNeeded() {
        guard galleryViewController.parent != nil else {
            return
        }
        galleryViewController.willMove(toParent: nil)
        galleryViewController.view.removeFromSuperview()
        galleryViewController.removeFromParent()
    }
    
}
