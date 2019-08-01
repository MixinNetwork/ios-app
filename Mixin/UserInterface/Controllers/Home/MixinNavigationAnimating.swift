import UIKit

enum MixinNavigationPushAnimation {
    case push
    case present
}

enum MixinNavigationPopAnimation {
    case pop
    case dismiss
}

protocol MixinNavigationAnimating {
    var pushAnimation: MixinNavigationPushAnimation { get }
    var popAnimation: MixinNavigationPopAnimation { get }
}

extension MixinNavigationAnimating {
    
    var pushAnimation: MixinNavigationPushAnimation {
        return .present
    }
    
    var popAnimation: MixinNavigationPopAnimation {
        return .dismiss
    }
    
}

final class PresentFromBottomAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    var operation: UINavigationController.Operation = .none
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.25
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if operation == .push {
            guard let toVC = transitionContext.viewController(forKey: .to),
                let toView = transitionContext.view(forKey: .to) else {
                    return
            }
            let containerView = transitionContext.containerView
            toView.frame = transitionContext.finalFrame(for: toVC)
            toView.frame.origin.y = toView.frame.size.height
            containerView.addSubview(toView)
            UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0, options: .curveEaseInOut, animations: {
                toView.frame = transitionContext.finalFrame(for: toVC)
            }, completion: { (finished) in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            })
        } else if operation == .pop {
            guard let fromView = transitionContext.view(forKey: .from),
                let toView = transitionContext.view(forKey: .to),
                let toVC = transitionContext.viewController(forKey: .to) else {
                    return
            }
            let containerView = transitionContext.containerView
            containerView.insertSubview(toView, belowSubview: fromView)
            toView.frame = transitionContext.finalFrame(for: toVC)
            UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0, options: .curveEaseInOut, animations: {
                fromView.frame.origin.y = fromView.frame.height
            }, completion: { (finished) in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            })
        }
    }
    
}
