import UIKit

class HittestBypassWrapperView: UIView {

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let hitTest = super.hitTest(point, with: event) {
            if hitTest == self {
                return nil
            } else {
                let shouldResponse = !hitTest.isHidden && hitTest.alpha > 0
                return shouldResponse ? hitTest : nil
            }
        } else {
            return nil
        }
    }

}
