import UIKit

class HomeContainerViewController: UIViewController {
    
    let homeNavigationController: HomeNavigationController = {
        let home = R.storyboard.home.home()!
        return HomeNavigationController(rootViewController: home)
    }()
    
    lazy var galleryViewController: GalleryViewController = {
        let controller = GalleryViewController()
        addChild(controller)
        view.insertSubview(controller.view, at: 0)
        controller.view.snp.makeEdgesEqualToSuperview()
        controller.didMove(toParent: self)
        return controller
    }()
    
    override var childForStatusBarHidden: UIViewController? {
        return homeNavigationController
    }
    
    override var childForHomeIndicatorAutoHidden: UIViewController? {
        return isShowingGallery ? galleryViewController : homeNavigationController
    }
    
    private var isShowingGallery: Bool {
        if view.subviews.last == homeNavigationController.view {
            return false
        } else if let (galleryIndex, homeIndex) = indices() {
            return galleryIndex > homeIndex
        } else {
            return false
        }
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
        NotificationCenter.default.addObserver(self, selector: #selector(galleryViewControllerWillShow(_:)), name: GalleryViewController.willShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(galleryViewControllerDidDismiss(_:)), name: GalleryViewController.didDismissNotification, object: nil)
    }
    
    @objc func galleryViewControllerWillShow(_ notification: Notification) {
        guard let (galleryIndex, homeIndex) = indices(), galleryIndex < homeIndex else {
            return
        }
        view.exchangeSubview(at: galleryIndex, withSubviewAt: homeIndex)
        UIApplication.shared.keyWindow?.windowLevel = .statusBar
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    @objc func galleryViewControllerDidDismiss(_ notification: Notification) {
        guard let (galleryIndex, homeIndex) = indices(), homeIndex < galleryIndex else {
            return
        }
        view.exchangeSubview(at: galleryIndex, withSubviewAt: homeIndex)
        UIApplication.shared.keyWindow?.windowLevel = .normal
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    private func indices() -> (gallery: Int, home: Int)? {
        guard let gallery = view.subviews.firstIndex(of: galleryViewController.view) else {
            return nil
        }
        guard let home = view.subviews.firstIndex(of: homeNavigationController.view) else {
            return nil
        }
        return (gallery, home)
    }
    
}
