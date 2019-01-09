import UIKit

class GrabbingWebViewController: UIViewController {
    
    @IBOutlet weak var backgroundDimmingView: UIView!
    @IBOutlet weak var grabberButton: GrabberButton!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var containerView: UIView!
    
    @IBOutlet weak var contentHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var showContentConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideContentConstraint: NSLayoutConstraint!
    
    let webViewController = WebViewController()
    
    private let animationDuration: TimeInterval = 0.5
    
    private var url: URL!
    private var conversationId = ""
    private var progressObserver: NSKeyValueObservation?
    
    static func instance(url: URL, conversationId: String) -> GrabbingWebViewController {
        let vc = Storyboard.common.instantiateViewController(withIdentifier: "grabbing_web") as! GrabbingWebViewController
        vc.url = url
        vc.conversationId = conversationId
        vc.modalPresentationStyle = .overCurrentContext 
        vc.transitioningDelegate = vc
        return vc
    }
    
    deinit {
        progressObserver?.invalidate()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        progressObserver = webViewController.webView.observe(\.estimatedProgress, changeHandler: { [weak self] (view, _) in
            self?.updateProgress(Float(view.estimatedProgress))
        })
        addChild(webViewController)
        containerView.addSubview(webViewController.view)
        webViewController.view.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
        webViewController.didMove(toParent: self)
        webViewController.conversationId = conversationId
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
    
    @IBAction func panAction(_ sender: UIPanGestureRecognizer) {
        let shouldDismiss = sender.location(in: view).y > view.bounds.height / 2
            || sender.velocity(in: view).y > 1000
        switch sender.state {
        case .began:
            grabberButton.chevronView.isDiagonal = false
        case .changed:
            let translation = sender.translation(in: view)
            showContentConstraint.constant -= translation.y / 2
            if shouldDismiss {
                dismiss(animated: true, completion: nil)
            }
            sender.setTranslation(.zero, in: view)
        case .ended:
            grabberButton.chevronView.isDiagonal = true
            if shouldDismiss {
                dismiss(animated: true, completion: nil)
            } else {
                showContentConstraint.constant = 0
                UIView.animate(withDuration: 0.3) {
                    self.view.layoutIfNeeded()
                }
            }
        default:
            break
        }
    }
    
    private func updateContentHeight() {
        let topDistance = max(UIApplication.shared.statusBarFrame.height,
                              view.compatibleSafeAreaInsets.top)
        contentHeightConstraint.constant = view.frame.height - topDistance
    }
    
    private func updateProgress(_ progress: Float) {
        progressView.setProgress(Float(progress), animated: progress > progressView.progress)
        if progress == 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.progressView.isHidden = self.webViewController.webView.estimatedProgress == 1
            }
        } else {
            progressView.isHidden = false
        }
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
                self.grabberButton.alpha = 1
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
                self.grabberButton.alpha = 0
            }) { (_) in
                self.view.removeFromSuperview()
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        }
    }
    
}
