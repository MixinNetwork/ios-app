import UIKit
import MixinServices

protocol PopupNavigationAnimating {
    var interactivePopOut: Bool { get }
}

extension PopupNavigationAnimating {
    
    var interactivePopOut: Bool {
        false
    }
    
}

final class PopInNavigationAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.3
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let toVC = transitionContext.viewController(forKey: .to),
            let toView = transitionContext.view(forKey: .to)
        else {
            transitionContext.completeTransition(false)
            return
        }
        let duration = transitionDuration(using: transitionContext)
        let containerView = transitionContext.containerView
        let tabBar: UITabBar?
        let tabBarSnapshot: UIView?
        if let fromVC = transitionContext.viewController(forKey: .from),
           !fromVC.hidesBottomBarWhenPushed,
           toVC.hidesBottomBarWhenPushed,
           let visibleTabBar = fromVC.tabBarController?.tabBar,
           !visibleTabBar.isHidden,
           let snapshot = visibleTabBar.snapshotView(afterScreenUpdates: false)
        {
            // UIKit slides the real tab bar horizontally when hiding it for a push.
            // Fade a stationary snapshot beneath the incoming popup instead.
            snapshot.frame = visibleTabBar.convert(visibleTabBar.bounds, to: containerView)
            containerView.addSubview(snapshot)
            tabBar = visibleTabBar
            tabBarSnapshot = snapshot
        } else {
            tabBar = nil
            tabBarSnapshot = nil
        }
        let tabBarAlpha = tabBar?.alpha
        tabBar?.alpha = 0
        toView.frame = transitionContext.finalFrame(for: toVC)
        toView.frame.origin.y = toView.frame.size.height
        containerView.addSubview(toView)
        UIView.animate(withDuration: duration, delay: 0, options: .overdampedCurve) {
            toView.frame = transitionContext.finalFrame(for: toVC)
            tabBarSnapshot?.alpha = 0
        } completion: { _ in
            let isCancelled = transitionContext.transitionWasCancelled
            if isCancelled {
                toView.removeFromSuperview()
            }
            transitionContext.completeTransition(!isCancelled)
            if let tabBarAlpha {
                tabBar?.alpha = tabBarAlpha
            }
            tabBarSnapshot?.removeFromSuperview()
        }
    }
    
}

final class PopOutNavigationAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        if let transitionContext, transitionContext.isInteractive {
            0.6
        } else {
            0.3
        }
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let fromView = transitionContext.view(forKey: .from),
            let toView = transitionContext.view(forKey: .to),
            let toVC = transitionContext.viewController(forKey: .to)
        else {
            transitionContext.completeTransition(false)
            return
        }
        let duration = transitionDuration(using: transitionContext)
        let containerView = transitionContext.containerView
        containerView.insertSubview(toView, belowSubview: fromView)
        toView.frame = transitionContext.finalFrame(for: toVC)
        if transitionContext.isInteractive {
            fromView.layer.cornerRadius = Device.current.bezelCornerRadius ?? 20
            fromView.layer.masksToBounds = true
            UIView.animateKeyframes(withDuration: duration, delay: 0, options: []) {
                UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.5) {
                    fromView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                }
                UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                    fromView.transform = CGAffineTransform(translationX: 0, y: containerView.bounds.height)
                        .scaledBy(x: 0.8, y: 0.8)
                }
            } completion: { _ in
                let isCancelled = transitionContext.transitionWasCancelled
                if isCancelled {
                    toView.removeFromSuperview()
                }
                transitionContext.completeTransition(!isCancelled)
                fromView.transform = .identity
                fromView.layer.cornerRadius = 0
            }
        } else {
            UIView.animate(withDuration: duration, delay: 0, options: .overdampedCurve) {
                fromView.frame.origin.y = fromView.frame.height
            } completion: { _ in
                let isCancelled = transitionContext.transitionWasCancelled
                if isCancelled {
                    toView.removeFromSuperview()
                }
                transitionContext.completeTransition(!isCancelled)
            }
        }
    }
    
}
