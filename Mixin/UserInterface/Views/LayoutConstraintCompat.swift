import UIKit

class LayoutConstraintCompat: NSLayoutConstraint {

    @IBInspectable
    var iphoneCompat: CGFloat = 0 {
        didSet {
            if UIDevice.current.userInterfaceIdiom == .phone && getScreenSize().height < 1920.0 {
                constant = self.iphoneCompat
            }
        }
    }

    private func getScreenSize() -> CGSize {
        var result = UIScreen.main.bounds.size
        if(UIScreen.main.responds(to: #selector(NSDecimalNumberBehaviors.scale))) {
            result = CGSize(width: result.width * UIScreen.main.scale, height: result.height * UIScreen.main.scale)
        }
        return result
    }

}
