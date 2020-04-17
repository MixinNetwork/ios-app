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
    
    private(set) var isPresentingAsChild = false
    
    // Override this variable and provides the scroll view
    var resizableScrollView: UIScrollView? {
        nil
    }
    
    lazy var resizeRecognizer = UIPanGestureRecognizer(target: self, action: #selector(changeSizeAction(_:)))
    
    private lazy var backgroundButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor.black.withAlphaComponent(0)
        button.addTarget(self, action: #selector(backgroundTappingAction), for: .touchUpInside)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateBottomInset()
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.cornerRadius = 13
        updatePreferredContentSizeHeight(size: size)
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
        guard size != .unavailable else {
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
                let translation = recognizer.translation(in: backgroundButton)
                var fractionComplete = translation.y / (backgroundButton.bounds.height - preferredContentHeight(forSize: .compressed))
                if size == .expanded {
                    fractionComplete *= -1
                }
                animator.fractionComplete = fractionComplete
            }
        case .ended:
            if let animator = sizeAnimator {
                let locationAboveBegan = recognizer.translation(in: backgroundButton).y <= 0
                let isGoingUp = recognizer.velocity(in: backgroundButton).y <= 0
                let locationUnderBegan = recognizer.translation(in: backgroundButton).y >= 0
                let isGoingDown = recognizer.velocity(in: backgroundButton).y >= 0
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
    
    @objc func backgroundTappingAction() {
        dismissAsChild(completion: nil)
    }
    
    func dismissAsChild(completion: (() -> Void)?) {
        guard !isPresentingAsChild else {
            return
        }
        UIView.animate(withDuration: 0.3, animations: {
            self.view.frame.origin.y = self.backgroundButton.bounds.height
            self.backgroundButton.backgroundColor = UIColor.black.withAlphaComponent(0)
        }) { (finished) in
            self.willMove(toParent: nil)
            self.view.removeFromSuperview()
            self.removeFromParent()
            self.backgroundButton.removeFromSuperview()
            completion?()
        }
    }
    
    func presentAsChild(of parent: UIViewController) {
        
        func realParent(of viewController: UIViewController) -> UIViewController {
            if let vc = viewController as? ResizablePopupViewController, let parent = vc.parent {
                return realParent(of: parent)
            } else if let container = viewController.container {
                return realParent(of: container)
            } else {
                return viewController
            }
        }
        
        let parent = realParent(of: parent)
        isPresentingAsChild = true
        loadViewIfNeeded()
        backgroundButton.frame = parent.view.bounds
        backgroundButton.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        parent.addChild(self)
        parent.view.addSubview(backgroundButton)
        didMove(toParent: parent)
        
        view.frame = CGRect(x: 0,
                            y: backgroundButton.bounds.height,
                            width: backgroundButton.bounds.width,
                            height: backgroundButton.bounds.height)
        view.autoresizingMask = .flexibleTopMargin
        backgroundButton.addSubview(view)
        UIView.animate(withDuration: 0.3, animations: {
            self.view.frame.origin.y = self.backgroundButton.bounds.height - self.preferredContentSize.height
            self.backgroundButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        }) { _ in
            self.isPresentingAsChild = false
        }
    }
    
    func updatePreferredContentSizeHeight(size: Size) {
        guard !isBeingDismissed else {
            return
        }
        let height = preferredContentHeight(forSize: size)
        preferredContentSize.height = height
        view.frame.origin.y = backgroundButton.bounds.height - height
    }
    
    func dismissAndPresent(_ viewController: UIViewController) {
        guard let parent = parent else {
            return
        }
        dismissAsChild {
            if let viewController = viewController as? ResizablePopupViewController {
                viewController.presentAsChild(of: parent)
            } else {
                parent.present(viewController, animated: true, completion: nil)
            }
        }
    }
    
    func dismissAndPush(_ viewController: UIViewController) {
        dismissAsChild {
            UIApplication.homeNavigationController?.pushViewController(viewController, animated: true)
        }
    }
    
    func updateBottomInset() {
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
        let window = AppDelegate.current.window
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
