import UIKit

class GrabbingWebViewController: UIViewController {
    
    @IBOutlet weak var backgroundDimmingView: UIView!
    @IBOutlet weak var containerView: UIView!
    
    @IBOutlet weak var contentHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var showContentConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideContentConstraint: NSLayoutConstraint!
    
    let webViewController = WebViewController()
    
    private let animationDuration: TimeInterval = 0.5
    
    private var url: URL!
    
    static func instance(url: URL) -> GrabbingWebViewController {
        let vc = Storyboard.common.instantiateViewController(withIdentifier: "grabbing_web") as! GrabbingWebViewController
        vc.url = url
        vc.modalPresentationStyle = .overCurrentContext 
        vc.transitioningDelegate = vc
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(webViewController)
        containerView.addSubview(webViewController.view)
        webViewController.view.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
        webViewController.didMove(toParent: self)
        webViewController.load(url: url)
        updateContentHeight()
    }
    
    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateContentHeight()
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    private func updateContentHeight() {
        let topDistance = max(UIApplication.shared.statusBarFrame.height,
                              view.compatibleSafeAreaInsets.top)
        contentHeightConstraint.constant = view.frame.height - topDistance
    }
    
}

extension GrabbingWebViewController: UIViewControllerTransitioningDelegate {
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return self
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return self
    }
    
}

extension GrabbingWebViewController: UIViewControllerAnimatedTransitioning {
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return animationDuration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if isBeingPresented {
            view.frame = transitionContext.finalFrame(for: self)
            transitionContext.containerView.addSubview(view)
            view.layoutIfNeeded()
            showContentConstraint.priority = .defaultHigh
            hideContentConstraint.priority = .defaultLow
            UIView.animate(withDuration: transitionDuration(using: transitionContext), animations: {
                UIView.setAnimationCurve(.overdamped)
                self.view.layoutIfNeeded()
                self.backgroundDimmingView.alpha = 1
            }) { (_) in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        } else if isBeingDismissed {
            hideContentConstraint.priority = .defaultHigh
            showContentConstraint.priority = .defaultLow
            UIView.animate(withDuration: transitionDuration(using: transitionContext), animations: {
                UIView.setAnimationCurve(.overdamped)
                self.view.layoutIfNeeded()
                self.backgroundDimmingView.alpha = 0
            }) { (_) in
                self.view.removeFromSuperview()
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        }
    }
    
}
