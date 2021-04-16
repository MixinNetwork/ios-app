import UIKit

class HomeContainerViewController: UIViewController {
    
    let clipSwitcher = ClipSwitcher()
    let overlaysCoordinator = HomeOverlaysCoordinator()
    
    var pipController: GalleryVideoItemViewController?
    
    let homeNavigationController: HomeNavigationController = {
        let home = R.storyboard.home.home()!
        return HomeNavigationController(rootViewController: home)
    }()
    
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
    
    private var navigationInteractiveGestureWasEnabled = true
    
    var galleryIsOnTopMost: Bool {
        isShowingGallery && galleryViewController.parent != nil
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
    
    @objc private func applicationWillEnterForeground(_ notification: Notification) {
        if UIApplication.shared.statusBarOrientation.isLandscape, let controller = pipController, controller.isAvPipActive {
            let portrait = Int(UIInterfaceOrientation.portrait.rawValue)
            UIDevice.current.setValue(portrait, forKey: "orientation")
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
            .compactMap({ $0 as? ContainerViewController })
            .compactMap({ $0.viewController as? SharedMediaViewController })
            .first(where: { $0.conversationId == conversationId })?
            .children
            .compactMap({ $0 as? SharedMediaMediaViewController })
            .first
        let conversation = homeNavigationController.viewControllers
            .compactMap({ $0 as? ConversationViewController })
            .first(where: { $0.conversationId == conversationId })
        return sharedMedia ?? conversation
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
