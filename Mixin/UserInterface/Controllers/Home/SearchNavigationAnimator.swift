import UIKit

protocol SearchNavigationAnimating: UIViewController {
    
}

final class SearchPushAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.2
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toViewController = transitionContext.viewController(forKey: .to),
              let toView = transitionContext.view(forKey: .to)
        else {
            transitionContext.completeTransition(false)
            return
        }
        let finalFrame = transitionContext.finalFrame(for: toViewController)
        toView.frame = finalFrame.offsetBy(dx: 0, dy: -28)
        toView.alpha = 0
        transitionContext.containerView.addSubview(toView)
        UIView.animate(withDuration: transitionDuration(using: transitionContext)) {
            toView.frame = finalFrame
            toView.alpha = 1
        } completion: { _ in
            let isCancelled = transitionContext.transitionWasCancelled
            toView.frame = finalFrame
            toView.alpha = 1
            if isCancelled {
                toView.removeFromSuperview()
            }
            transitionContext.completeTransition(!isCancelled)
        }
    }
    
}

final class SearchPopAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.2
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toViewController = transitionContext.viewController(forKey: .to),
              let toView = transitionContext.view(forKey: .to),
              let fromView = transitionContext.view(forKey: .from)
        else {
            transitionContext.completeTransition(false)
            return
        }
        let initialFrame = fromView.frame
        toView.frame = transitionContext.finalFrame(for: toViewController)
        transitionContext.containerView.insertSubview(toView, belowSubview: fromView)
        UIView.animate(withDuration: transitionDuration(using: transitionContext)) {
            fromView.frame = initialFrame.offsetBy(dx: 0, dy: -28)
            fromView.alpha = 0
        } completion: { _ in
            let isCancelled = transitionContext.transitionWasCancelled
            if isCancelled {
                toView.removeFromSuperview()
            }
            transitionContext.completeTransition(!isCancelled)
            fromView.frame = initialFrame
            fromView.alpha = 1
        }
    }
    
}
