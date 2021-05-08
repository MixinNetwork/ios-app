import UIKit

class FullscreenPopupViewController: UIViewController {
    
    @IBOutlet weak var contentView: SolidBackgroundColoredView!
    @IBOutlet weak var pageControlView: PageControlView!
    
    @IBOutlet weak var edgePanGestureRecognizer: FullScreenPopupEdgePanGestureRecognizer!
    
    private(set) var isBeingDismissedAsChild = false
    
    private var statusBarStyle = UIStatusBarStyle.default
    
    override func viewDidLoad() {
        super.viewDidLoad()
        contentView.backgroundColorIgnoringSystemSettings = .background
        pageControlView.moreButton.addTarget(self, action: #selector(moreAction(_:)), for: .touchUpInside)
        pageControlView.dismissButton.addTarget(self, action: #selector(dismissAction(_:)), for: .touchUpInside)
    }
    
    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            self.parent?.setNeedsStatusBarAppearanceUpdate()
            self.parent?.setNeedsUpdateOfHomeIndicatorAutoHidden()
        }
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        parent?.setNeedsStatusBarAppearanceUpdate()
        parent?.setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismissAsChild(animated: true)
    }
    
    @IBAction func screenEdgePanAction(_ recognizer: FullScreenPopupEdgePanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            if view.safeAreaInsets.top > 20 {
                contentView.layer.cornerRadius = 39
            } else {
                contentView.layer.cornerRadius = 20
            }
        case .changed:
            let scale = 1 - 0.2 * recognizer.fractionComplete
            contentView.transform = CGAffineTransform(scaleX: scale, y: scale)
        case .ended:
            dismissAsChild(animated: true)
        case .cancelled:
            UIView.animate(withDuration: 0.25, animations: {
                self.contentView.transform = .identity
            }, completion: { _ in
                self.contentView.layer.cornerRadius = 0
            })
        default:
            break
        }
    }
    
    @objc func moreAction(_ sender: Any) {
        
    }
    
    func presentAsChild(of parent: UIViewController, completion: (() -> Void)?) {
        AppDelegate.current.mainWindow.endEditing(true)
        
        view.frame = parent.view.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        parent.addChild(self)
        if let view = parent.view as? UIVisualEffectView {
            view.contentView.addSubview(view)
        } else {
            parent.view.addSubview(view)
        }
        didMove(toParent: parent)
        
        view.center.y = parent.view.bounds.height * 3 / 2
        UIView.animate(withDuration: 0.5) {
            UIView.setAnimationCurve(.overdamped)
            self.view.center.y = parent.view.bounds.height / 2
        } completion: { (_) in
            completion?()
        }
    }
    
    func dismissAsChild(animated: Bool, completion: (() -> Void)? = nil) {
        guard let parent = parent else {
            return
        }
        isBeingDismissedAsChild = true
        parent.setNeedsStatusBarAppearanceUpdate()
        let animation = {
            UIView.setAnimationCurve(.overdamped)
            self.view.center.y = parent.view.bounds.height * 3 / 2
        }
        let animationCompletion = {
            self.willMove(toParent: nil)
            self.view.removeFromSuperview()
            self.removeFromParent()
            completion?()
            self.contentView.transform = .identity
            self.isBeingDismissedAsChild = false
            self.popupDidDismissAsChild()
        }
        if animated {
            UIView.animate(withDuration: 0.5, animations: animation) { (_) in
                animationCompletion()
            }
        } else {
            animation()
            animationCompletion()
        }
    }
    
    func popupDidDismissAsChild() {
        
    }
    
}
