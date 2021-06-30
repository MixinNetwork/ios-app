import UIKit

class ResizablePopupViewController: UIViewController {
    
    enum Size {
        
        case expanded
        case compressed
        case unavailable
        
        var opposite: Size {
            switch self {
            case .expanded:
                return .compressed
            case .compressed:
                return .expanded
            case .unavailable:
                return .unavailable
            }
        }
        
    }
    
    var size = Size.compressed
    var sizeAnimator: UIViewPropertyAnimator?
    
    // Override this variable and provides the scroll view
    var resizableScrollView: UIScrollView? {
        nil
    }
    
    var automaticallyAdjustsResizableScrollViewBottomInset: Bool {
        true
    }
    
    lazy var resizeRecognizer = UIPanGestureRecognizer(target: self, action: #selector(changeSizeAction(_:)))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateBottomInset()
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.cornerRadius = 13
        setNeedsSizeAppearanceUpdated(size: size)
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateBottomInset()
        updatePreferredContentSizeHeight(size: size)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory else {
            return
        }
        DispatchQueue.main.async {
            self.updatePreferredContentSizeHeight(size: self.size)
        }
    }
    
    @objc func changeSizeAction(_ recognizer: UIPanGestureRecognizer) {
        guard size != .unavailable, let superview = view.superview else {
            return
        }
        switch recognizer.state {
        case .began:
            resizableScrollView?.isScrollEnabled = false
            size = size.opposite
            let animator = makeSizeAnimator(destination: size)
            animator.pauseAnimation()
            sizeAnimator = animator
        case .changed:
            if let animator = sizeAnimator {
                let translation = recognizer.translation(in: superview)
                var fractionComplete = translation.y / (superview.bounds.height - preferredContentHeight(forSize: .compressed))
                if size == .expanded {
                    fractionComplete *= -1
                }
                animator.fractionComplete = fractionComplete
            }
        case .ended:
            if let animator = sizeAnimator {
                let locationAboveBegan = recognizer.translation(in: superview).y <= 0
                let isGoingUp = recognizer.velocity(in: superview).y <= 0
                let locationUnderBegan = recognizer.translation(in: superview).y >= 0
                let isGoingDown = recognizer.velocity(in: superview).y >= 0
                let shouldExpand = size == .expanded
                    && ((locationAboveBegan && isGoingUp) || isGoingUp)
                let shouldCompress = size == .compressed
                    && ((locationUnderBegan && isGoingDown) || isGoingDown)
                let shouldReverse = !shouldExpand && !shouldCompress
                let completionSize = shouldReverse ? size.opposite : size
                animator.isReversed = shouldReverse
                animator.addCompletion { (position) in
                    self.size = completionSize
                    self.updatePreferredContentSizeHeight(size: completionSize)
                    self.setNeedsSizeAppearanceUpdated(size: completionSize)
                    self.sizeAnimator = nil
                    recognizer.isEnabled = true
                }
                recognizer.isEnabled = false
                animator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
            }
        default:
            break
        }
    }

    func updatePreferredContentSizeHeight(size: Size) {
        guard !isBeingDismissed else {
            return
        }
        preferredContentSize.height = preferredContentHeight(forSize: size)
    }
    
    func dismissAndPresent(_ viewController: UIViewController) {
        let presenting = presentingViewController
        dismiss(animated: true) {
            presenting?.present(viewController, animated: true, completion: nil)
        }
    }
    
    func dismissAndPush(_ viewController: UIViewController) {
        dismiss(animated: true) {
            UIApplication.homeNavigationController?.pushViewController(viewController, animated: true)
        }
    }
    
    func updateBottomInset() {
        guard automaticallyAdjustsResizableScrollViewBottomInset else {
            return
        }
        guard let scrollView = resizableScrollView else {
            return
        }
        if view.safeAreaInsets.bottom > 5 {
            scrollView.contentInset.bottom = 5
        } else {
            scrollView.contentInset.bottom = 30
        }
    }
    
    func setNeedsSizeAppearanceUpdated(size: Size) {
        guard let scrollView = resizableScrollView else {
            return
        }
        switch size {
        case .expanded:
            scrollView.isScrollEnabled = true
            scrollView.alwaysBounceVertical = true
        case .compressed:
            scrollView.contentOffset = .zero
            scrollView.isScrollEnabled = false
            scrollView.alwaysBounceVertical = false
        case .unavailable:
            scrollView.isScrollEnabled = true
            scrollView.alwaysBounceVertical = true
        }
    }
    
    func preferredContentHeight(forSize size: Size) -> CGFloat {
        view.layoutIfNeeded()
        let window = AppDelegate.current.mainWindow
        let maxHeight = window.bounds.height - window.safeAreaInsets.top
        return maxHeight
    }
    
    func makeSizeAnimator(destination: Size) -> UIViewPropertyAnimator {
        let overdamped = UISpringTimingParameters()
        let animator = UIViewPropertyAnimator(duration: 0.5, timingParameters: overdamped)
        animator.addAnimations {
            self.updatePreferredContentSizeHeight(size: destination)
            self.setNeedsSizeAppearanceUpdated(size: destination)
        }
        return animator
    }
    
}
