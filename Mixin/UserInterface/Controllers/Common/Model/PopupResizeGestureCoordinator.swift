import UIKit

class PopupResizeGestureCoordinator: NSObject, UIGestureRecognizerDelegate {
    
    weak var scrollView: UIScrollView?
    
    init(scrollView: UIScrollView?) {
        self.scrollView = scrollView
        super.init()
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let scrollView = scrollView else {
            return true
        }
        let canDragDown: Bool
        if let recognizer = gestureRecognizer as? UIPanGestureRecognizer {
            canDragDown = abs(scrollView.contentOffset.y) < 0.1 && recognizer.velocity(in: nil).y > 0
        } else {
            canDragDown = false
        }
        return !scrollView.isScrollEnabled || canDragDown
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
}
