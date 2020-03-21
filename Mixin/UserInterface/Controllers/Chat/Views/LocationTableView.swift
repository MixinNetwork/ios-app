import UIKit

class LocationTableWrapperView: UIView {
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let superHitTest = super.hitTest(point, with: event)
        guard let mask = mask else {
            return superHitTest
        }
        if mask.frame.contains(point) {
            return superHitTest
        } else {
            return nil
        }
    }
    
}
