import UIKit

class SearchNavigationController: MixinNavigationController {

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }

    var searchViewController: SearchViewController {
        return viewControllers[0] as! SearchViewController
    }
    
    private func prepare() {
        transitioningDelegate = self
    }
    
}

extension SearchNavigationController: UIViewControllerTransitioningDelegate {
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return PresentAnimator()
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return DismissAnimator()
    }

}

extension SearchNavigationController {
    
    class PresentAnimator: NSObject, UIViewControllerAnimatedTransitioning {
        
        private let animationDuration: TimeInterval = 0.35
        
        func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
            return animationDuration
        }
        
        func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
            guard let toView = transitionContext.view(forKey: .to), let toVC = transitionContext.viewController(forKey: .to) else {
                return
            }
            toView.frame = transitionContext.finalFrame(for: toVC)
            transitionContext.containerView.addSubview(toView)
            toView.layoutIfNeeded()
            if let toVC = toVC as? SearchNavigationController {
                toVC.searchViewController.layoutForPresentAnimation()
            }
            UIView.animate(withDuration: animationDuration, animations: {
                toView.layoutIfNeeded()
            }) { (_) in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        }
        
    }
    
    class DismissAnimator: NSObject, UIViewControllerAnimatedTransitioning {
       
        private let animationDuration: TimeInterval = 0.25
        
        func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
            return animationDuration
        }
        
        func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
            guard let toView = transitionContext.view(forKey: .to),let fromView = transitionContext.view(forKey: .from), let toVC = transitionContext.viewController(forKey: .to) else {
                return
            }
            toView.frame = transitionContext.finalFrame(for: toVC)
            transitionContext.containerView.insertSubview(toView, belowSubview: fromView)
            UIView.animate(withDuration: animationDuration, animations: {
                fromView.alpha = 0
            }) { (_) in
                fromView.removeFromSuperview()
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        }
        
    }
    
}
