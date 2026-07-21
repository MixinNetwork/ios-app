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
        toView.frame = transitionContext.finalFrame(for: toVC)
        toView.frame.origin.y = toView.frame.size.height
        containerView.addSubview(toView)
        UIView.animate(withDuration: duration, delay: 0, options: .overdampedCurve) {
            toView.frame = transitionContext.finalFrame(for: toVC)
        } completion: { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
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
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                fromView.transform = .identity
                fromView.layer.cornerRadius = 0
            }
        } else {
            UIView.animate(withDuration: duration, delay: 0, options: .overdampedCurve) {
                fromView.frame.origin.y = fromView.frame.height
            } completion: { _ in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        }
    }
    
}
