import UIKit

class PopupPresentationController: UIPresentationController {
    
    private lazy var backgroundView = makeBackgroundView()
    
    private var isTransitioning = false
    
    override var frameOfPresentedViewInContainerView: CGRect {
        let maxBounds = containerView?.bounds ?? presentingViewController.view.bounds
        if presentedViewController.preferredContentSize != .zero {
            let height = min(maxBounds.height, presentedViewController.preferredContentSize.height)
            return CGRect(x: 0,
                          y: maxBounds.height - height,
                          width: maxBounds.width,
                          height: height)
        } else {
            return maxBounds
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
            backgroundView.frame = containerView.bounds
            backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            containerView.insertSubview(backgroundView, at: 0)
        }
        guard let coordinator = presentedViewController.transitionCoordinator else {
            backgroundView.alpha = 1
            return
        }
        coordinator.animate(alongsideTransition: { (_) in
            self.backgroundView.alpha = 1
        })
    }
    
    override func presentationTransitionDidEnd(_ completed: Bool) {
        isTransitioning = false
    }
    
    override func dismissalTransitionWillBegin() {
        isTransitioning = true
        guard let coordinator = presentedViewController.transitionCoordinator else {
            backgroundView.alpha = 0
            return
        }
        coordinator.animate(alongsideTransition: { (_) in
            self.backgroundView.alpha = 0
        })
    }
    
    override func dismissalTransitionDidEnd(_ completed: Bool) {
        isTransitioning = false
    }
    
    func makeBackgroundView() -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        return view
    }
    
    private func updatePresentedViewFrame() {
        presentedView?.frame = frameOfPresentedViewInContainerView
    }
    
}
