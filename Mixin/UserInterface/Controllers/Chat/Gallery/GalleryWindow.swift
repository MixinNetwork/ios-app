import UIKit

final class GalleryWindow: Window {
    
    let galleryViewController = GalleryViewController()
    
    private var transitionViewController: GalleryTransitionViewController?
    
    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        backgroundColor = .clear
        rootViewController = galleryViewController
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func beginTransition(
        in mainWindow: UIWindow,
        backgroundAlpha: CGFloat,
        completion: @escaping (GalleryTransitionViewController) -> Void,
    ) {
        guard var presenter = mainWindow.rootViewController else {
            return
        }
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        let controller = GalleryTransitionViewController(backgroundAlpha: backgroundAlpha)
        controller.view.frame = mainWindow.bounds
        transitionViewController = controller
        presenter.present(controller, animated: false) { [weak self] in
            guard self?.transitionViewController === controller else {
                controller.dismiss(animated: false)
                return
            }
            completion(controller)
        }
    }
    
    func endTransition(completion: (() -> Void)?) {
        let controller = transitionViewController
        transitionViewController = nil
        controller?.backgroundView.layer.removeAllAnimations()
        if let controller, !controller.isBeingPresented {
            controller.dismiss(animated: false, completion: completion)
        } else {
            // An interrupted presentation dismisses itself in its completion handler.
            completion?()
        }
    }
    
}
