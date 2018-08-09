import UIKit

enum MixinNavigationPushAnimation {
    case push
    case present
    case reversedPush
}

enum MixinNavigationPopAnimation {
    case pop
    case dismiss
    case reversedPop
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

class MixinNavigationController: UINavigationController {

    fileprivate let presentFromBottomAnimator = PresentFromBottomAnimator()
    fileprivate let pushFromLeftAnimator = PushFromLeftAnimator()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.interactivePopGestureRecognizer?.isEnabled = true
        self.interactivePopGestureRecognizer?.delegate = self
        self.isNavigationBarHidden = true
        self.delegate = self
    }

}

extension MixinNavigationController: UINavigationControllerDelegate {

    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationControllerOperation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if operation == .push {
            var targetVC = toVC
            if toVC is ContainerViewController {
                targetVC = (toVC as! ContainerViewController).viewController
            }
            if let targetVC = targetVC as? MixinNavigationAnimating {
                switch targetVC.pushAnimation {
                case .push:
                    return nil
                case .reversedPush :
                    pushFromLeftAnimator.operation = operation
                    return pushFromLeftAnimator
                case .present:
                    presentFromBottomAnimator.operation = operation
                    return presentFromBottomAnimator
                }
            }
        } else if operation == .pop {
            var targetVC = fromVC
            if fromVC is ContainerViewController {
                targetVC = (fromVC as! ContainerViewController).viewController
            }
            if let targetVC = targetVC as? MixinNavigationAnimating {
                switch targetVC.popAnimation {
                case .pop:
                    return nil
                case .reversedPop :
                    pushFromLeftAnimator.operation = operation
                    return pushFromLeftAnimator
                case .dismiss:
                    presentFromBottomAnimator.operation = operation
                    return presentFromBottomAnimator
                }
            }
        }
        return nil
    }

}

extension MixinNavigationController: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard viewControllers.count > 1 else {
            return false
        }
        if let vc = viewControllers.last as? MixinNavigationAnimating {
            return vc.popAnimation != .reversedPop
        } else {
            return true
        }
    }

}

fileprivate class PresentFromBottomAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    var operation: UINavigationControllerOperation = .none

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

fileprivate class PushFromLeftAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    var operation: UINavigationControllerOperation = .none

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.25
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if operation == .push {
            guard let fromView = transitionContext.view(forKey: .from), let toVC = transitionContext.viewController(forKey: .to),
                let toView = transitionContext.view(forKey: .to) else {
                    return
            }
            let containerView = transitionContext.containerView
            toView.frame = transitionContext.finalFrame(for: toVC)
            toView.frame.origin.x = -toView.frame.size.width
            containerView.addSubview(toView)
            UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0, options: [.curveEaseInOut, .transitionFlipFromLeft], animations: {
                fromView.frame.origin.x = fromView.frame.size.width
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
            toView.frame.origin.x = fromView.frame.size.width
            UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0, options: [.curveEaseInOut, .transitionFlipFromRight], animations: {
                toView.frame.origin.x = 0
                fromView.frame.origin.x = -fromView.frame.width
            }, completion: { (finished) in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            })
        }
    }

}
