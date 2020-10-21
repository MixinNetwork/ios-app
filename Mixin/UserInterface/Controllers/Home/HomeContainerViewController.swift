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
        let controller = MinimizedCallViewController()
        controller.view.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin]
        addChild(controller)
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        controller.updateViewSize()
        controller.panningController.placeViewNextToLastOverlayOrTopRight()
        overlaysCoordinator.register(overlay: controller.view)
        minimizedCallViewControllerIfLoaded = controller
        return controller
    }()
    
    lazy var minimizedClipSwitcherViewController: MinimizedClipSwitcherViewController = {
        let controller = MinimizedClipSwitcherViewController()
        controller.view.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin]
        addChild(controller)
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        controller.updateViewSize()
        controller.panningController.placeViewNextToLastOverlayOrTopRight()
        overlaysCoordinator.register(overlay: controller.view)
        return controller
    }()
        
    override var childForStatusBarHidden: UIViewController? {
        return galleryIsOnTopMost ? galleryViewController : homeNavigationController
    }
    
    override var childForStatusBarStyle: UIViewController? {
        return galleryIsOnTopMost ? galleryViewController : homeNavigationController
    }
    
    override var childForHomeIndicatorAutoHidden: UIViewController? {
        return galleryIsOnTopMost ? galleryViewController : homeNavigationController
    }
    
    private(set) var isShowingGallery = false
    private(set) var galleryViewControllerIfLoaded: GalleryViewController?
    
    private(set) weak var minimizedCallViewControllerIfLoaded: MinimizedCallViewController?
    
    private var navigationInteractiveGestureWasEnabled = true
    
    var galleryIsOnTopMost: Bool {
        isShowingGallery && galleryViewController.parent != nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(homeNavigationController)
        view.addSubview(homeNavigationController.view)
        homeNavigationController.view.snp.makeEdgesEqualToSuperview()
        homeNavigationController.didMove(toParent: self)
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
