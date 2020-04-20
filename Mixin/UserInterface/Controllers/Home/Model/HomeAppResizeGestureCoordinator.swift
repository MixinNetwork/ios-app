import UIKit

class HomeAppResizeGestureCoordinator: PopupResizeGestureCoordinator {
    
    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return otherGestureRecognizer == scrollView?.panGestureRecognizer
    }
    
}
