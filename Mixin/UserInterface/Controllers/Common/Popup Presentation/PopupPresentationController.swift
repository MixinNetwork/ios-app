import UIKit

class PopupPresentationController: UIPresentationController {
    
    lazy var backgroundButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        button.alpha = 0
        button.addTarget(self, action: #selector(backgroundTapAction(sender:)), for: .touchUpInside)
        return button
    }()
    
    let topMargin: CGFloat = 56
    
    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView = containerView else {
            return presentedViewController.view.bounds
        }
        let height = containerView.bounds.height
            - containerView.compatibleSafeAreaInsets.top
            - topMargin
        let y = containerView.bounds.height - height
        return CGRect(x: 0, y: y, width: containerView.bounds.width, height: height)
    }
    
    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
    }
    
    override func presentationTransitionWillBegin() {
        if let containerView = containerView {
            backgroundButton.frame = containerView.bounds
            backgroundButton.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            containerView.insertSubview(backgroundButton, at: 0)
        }
        guard let coordinator = presentedViewController.transitionCoordinator else {
            backgroundButton.alpha = 1
            return
        }
        coordinator.animate(alongsideTransition: { (_) in
            self.backgroundButton.alpha = 1
        })
    }
    
    override func dismissalTransitionWillBegin() {
        guard let coordinator = presentedViewController.transitionCoordinator else {
            backgroundButton.alpha = 0
            return
        }
        coordinator.animate(alongsideTransition: { (_) in
            self.backgroundButton.alpha = 0
        })
    }
    
    @objc func backgroundTapAction(sender: Any) {
        presentingViewController.dismiss(animated: true, completion: nil)
    }
    
}
