import UIKit

class PopupPresentationController: UIPresentationController {
    
    static let willDismissPresentedViewControllerNotification = Notification.Name("one.mixin.messenger.PopupPresentationController.WillDismissPresentedViewController")
    static let didDismissPresentedViewControllerNotification = Notification.Name("one.mixin.messenger.PopupPresentationController.DidDismissPresentedViewController")
    
    lazy var backgroundButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        button.alpha = 0
        button.addTarget(self, action: #selector(backgroundTapAction(sender:)), for: .touchUpInside)
        return button
    }()
    
    private var isTransitioning = false
    
    override var frameOfPresentedViewInContainerView: CGRect {
        let presentingBounds = presentingViewController.view.bounds
        if presentedViewController.preferredContentSize != .zero {
            let height = min(presentingBounds.height, presentedViewController.preferredContentSize.height)
            return CGRect(x: 0,
                          y: presentingBounds.height - height,
                          width: presentingBounds.width,
                          height: height)
        } else {
            return presentingBounds
        }
    }
    
    override func preferredContentSizeDidChange(forChildContentContainer container: UIContentContainer) {
        super.preferredContentSizeDidChange(forChildContentContainer: container)
        if isTransitioning {
            DispatchQueue.main.async(execute: updatePresentedViewFrame)
        } else {
            updatePresentedViewFrame()
        }
    }
    
    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        if isTransitioning {
            DispatchQueue.main.async(execute: updatePresentedViewFrame)
        } else {
            updatePresentedViewFrame()
        }
    }
    
    override func presentationTransitionWillBegin() {
        isTransitioning = true
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
    
    override func presentationTransitionDidEnd(_ completed: Bool) {
        isTransitioning = false
    }
    
    override func dismissalTransitionWillBegin() {
        isTransitioning = true
        guard let coordinator = presentedViewController.transitionCoordinator else {
            backgroundButton.alpha = 0
            return
        }
        coordinator.animate(alongsideTransition: { (_) in
            self.backgroundButton.alpha = 0
        })
    }
    
    override func dismissalTransitionDidEnd(_ completed: Bool) {
        isTransitioning = false
    }
    
    @objc func backgroundTapAction(sender: Any) {
        NotificationCenter.default.post(name: Self.willDismissPresentedViewControllerNotification, object: self)
        presentingViewController.dismiss(animated: true) {
            NotificationCenter.default.post(name: Self.didDismissPresentedViewControllerNotification, object: self)
        }
    }
    
    private func updatePresentedViewFrame() {
        presentedView?.frame = frameOfPresentedViewInContainerView
    }
    
}
