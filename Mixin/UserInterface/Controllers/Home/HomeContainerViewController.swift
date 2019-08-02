import UIKit

class HomeContainerViewController: UIViewController {
    
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
        return isShowingGallery ? galleryViewController : homeNavigationController
    }
    
    override var childForHomeIndicatorAutoHidden: UIViewController? {
        return isShowingGallery ? galleryViewController : homeNavigationController
    }
    
    private var isShowingGallery = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(homeNavigationController)
        view.addSubview(homeNavigationController.view)
        homeNavigationController.view.snp.makeEdgesEqualToSuperview()
        homeNavigationController.didMove(toParent: self)
    }
    
    private func conversationViewController(of conversationId: String) -> ConversationViewController? {
        return homeNavigationController.viewControllers
            .compactMap({ $0 as? ConversationViewController })
            .first(where: { $0.conversationId == conversationId })
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
    
    func galleryViewController(_ viewController: GalleryViewController, cellFor item: GalleryItem) -> PhotoRepresentableMessageCell? {
        return conversationViewController(of: item.conversationId)?.galleryViewController(viewController, cellFor: item)
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
        if let vc = conversationViewController(of: item.conversationId) {
            vc.galleryViewController(viewController, willShow: item)
        }
    }
    
    func galleryViewController(_ viewController: GalleryViewController, didShow item: GalleryItem) {
        isShowingGallery = true
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        if let vc = conversationViewController(of: item.conversationId) {
            vc.galleryViewController(viewController, didShow: item)
        }
    }
    
    func galleryViewController(_ viewController: GalleryViewController, willDismiss item: GalleryItem) {
        if let vc = conversationViewController(of: item.conversationId) {
            vc.galleryViewController(viewController, willDismiss: item)
        }
    }
    
    func galleryViewController(_ viewController: GalleryViewController, didDismiss item: GalleryItem, relativeOffset: CGFloat?) {
        removeGalleryFromItsParentIfNeeded()
        isShowingGallery = false
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        if let vc = conversationViewController(of: item.conversationId) {
            vc.galleryViewController(viewController, didDismiss: item, relativeOffset: relativeOffset)
        }
    }
    
    func galleryViewController(_ viewController: GalleryViewController, didCancelDismissalFor item: GalleryItem) {
        if let vc = conversationViewController(of: item.conversationId) {
            vc.galleryViewController(viewController, didCancelDismissalFor: item)
        }
    }
    
}
