import UIKit

final class PerpsPositionValueTextField: UITextField {
    
    override var font: UIFont? {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }
    
    override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        if let font {
            // Keep text and the zero placeholder the same height as the font changes.
            size.height = font.lineHeight.rounded(.up)
        }
        return size
    }
    
}
