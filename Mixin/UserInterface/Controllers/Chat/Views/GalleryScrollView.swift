import UIKit

class GalleryScrollView: UIScrollView {

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitTest = super.hitTest(point, with: event)
        isScrollEnabled = !(hitTest is UISlider)
        return hitTest
    }

}
