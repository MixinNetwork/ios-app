import UIKit

final class PopupPresentationAnimator: NSObject {
    
    let isPresenting: Bool
    
    @available(*, unavailable)
    override init() {
        fatalError()
    }
    
    init(isPresenting: Bool) {
        self.isPresenting = isPresenting
        super.init()
    }
    
}

extension PopupPresentationAnimator: UIViewControllerAnimatedTransitioning {
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.5
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let container = transitionContext.containerView
        let duration = transitionDuration(using: transitionContext)
        let vc: UIViewController
        if isPresenting {
            vc = transitionContext.viewController(forKey: .to)!
            let finalFrame = transitionContext.finalFrame(for: vc)
            let view = transitionContext.view(forKey: .to)!
            view.frame = CGRect(x: finalFrame.origin.x,
                                y: container.bounds.height,
                                width: finalFrame.width,
                                height: finalFrame.height)
            container.addSubview(view)
            UIView.animate(withDuration: duration, delay: 0, options: .overdampedCurve, animations: {
                view.frame = finalFrame
            }, completion: transitionContext.completeTransition(_:))
        } else {
            vc = transitionContext.viewController(forKey: .from)!
            let view = transitionContext.view(forKey: .from)!
            UIView.animate(withDuration: duration, delay: 0, options: .overdampedCurve, animations: {
                view.frame = CGRect(x: view.frame.origin.x,
                                    y: container.bounds.height,
                                    width: view.frame.width,
                                    height: view.frame.height)
            }, completion: transitionContext.completeTransition(_:))
        }
    }
    
}
