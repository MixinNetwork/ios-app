import UIKit

class ScreenSizeCompatibleLayoutConstraint: NSLayoutConstraint {
    
    @IBInspectable var inch4: CGFloat = 0 {
        didSet {
            updateConstraint(trait: .inch4, value: inch4)
        }
    }
    
    @IBInspectable var inch4_7: CGFloat = 0 {
        didSet {
            updateConstraint(trait: .inch4_7, value: inch4_7)
        }
    }
    
    @IBInspectable var inch5_5: CGFloat = 0 {
        didSet {
            updateConstraint(trait: .inch5_5, value: inch5_5)
        }
    }
    
    @IBInspectable var inch5_8: CGFloat = 0 {
        didSet {
            updateConstraint(trait: .inch5_8, value: inch5_8)
        }
    }
    
    private func updateConstraint(trait: ScreenSize, value: CGFloat) {
        guard trait == ScreenSize.current else {
            return
        }
        constant = value
    }
    
}
