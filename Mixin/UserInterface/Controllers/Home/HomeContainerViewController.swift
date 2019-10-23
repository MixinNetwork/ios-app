import UIKit

class HomeContainerViewController: UIViewController {
    
    var pipController: GalleryVideoItemViewController?
    
    let homeNavigationController: HomeNavigationController = {
        let home = R.storyboard.home.home()!
        return HomeNavigationController(rootViewController: home)
    }()
    
    lazy var galleryViewController: GalleryViewController = {
        let controller = GalleryViewController()
        controller.delegate = self
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
    
    private var galleryIsOnTopMost: Bool {
        return isShowingGallery
            && galleryViewController.parent != nil
            && galleryViewController.parent == homeNavigationController.viewControllers.last
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
        let topMostViewController = homeNavigationController.viewControllers.last ?? self
        topMostViewController.addChild(viewController)
        topMostViewController.view.addSubview(viewController.view)
        viewController.view.snp.makeEdgesEqualToSuperview()
        viewController.didMove(toParent: topMostViewController)
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
        isShowingGallery = true
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        chainingDelegate(of: item.conversationId)?.galleryViewController(viewController, willShow: item)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, didShow item: GalleryItem) {
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
    }
    
    func galleryViewController(_ viewController: GalleryViewController, didCancelDismissalFor item: GalleryItem) {
        chainingDelegate(of: item.conversationId)?.galleryViewController(viewController, didCancelDismissalFor: item)
    }
    
}
