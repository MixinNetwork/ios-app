import UIKit

class GalleryView: UIView {
    
    weak var scrollView: UIScrollView?
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitTest = super.hitTest(point, with: event)
        scrollView?.isScrollEnabled = !(hitTest is UISlider)
        return hitTest
    }
    
}
