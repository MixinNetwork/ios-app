import UIKit

final class BackgroundDismissablePopupPresentationManager: NSObject, UIViewControllerTransitioningDelegate {
    
    static let shared = BackgroundDismissablePopupPresentationManager()
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        PopupPresentationAnimator(isPresenting: true)
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        PopupPresentationAnimator(isPresenting: false)
    }
    
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        BackgroundDismissablePopupPresentationController(presentedViewController: presented, presenting: presenting)
    }
    
}
