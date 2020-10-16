import UIKit

class ScreenHeightCompatibleLayoutConstraint: NSLayoutConstraint {
    
    @IBInspectable var shortConstant: CGFloat = .nan {
        didSet {
            updateConstant(shortConstant, for: .short)
        }
    }
    
    @IBInspectable var mediumConstant: CGFloat = .nan {
        didSet {
            updateConstant(mediumConstant, for: .medium)
        }
    }
    
    @IBInspectable var longConstant: CGFloat = .nan {
        didSet {
            updateConstant(longConstant, for: .long)
        }
    }
    
    @IBInspectable var extraLongConstant: CGFloat = .nan {
        didSet {
            updateConstant(extraLongConstant, for: .extraLong)
        }
    }
    
    private func updateConstant(_ constant: CGFloat, for height: ScreenHeight) {
        guard height == ScreenHeight.current, !constant.isNaN else {
            return
        }
        self.constant = constant
    }
    
}
