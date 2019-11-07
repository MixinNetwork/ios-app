import UIKit

final class ProfileScrollView: UIScrollView {
    
    override func touchesShouldCancel(in view: UIView) -> Bool {
        return view is UIButton || super.touchesShouldCancel(in: view)
    }
    
}
