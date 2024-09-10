import UIKit

class InsetLabel: UILabel {
    
    var contentInset: UIEdgeInsets = .zero {
        didSet {
            invertedContentInset = UIEdgeInsets(top: -contentInset.top,
                                                left: -contentInset.left,
                                                bottom: -contentInset.bottom,
                                                right: -contentInset.right)
            invalidateIntrinsicContentSize()
        }
    }
    
    private var invertedContentInset: UIEdgeInsets = .zero
    
    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let layoutBounds = bounds.inset(by: contentInset)
        let textRect = super.textRect(forBounds: layoutBounds, limitedToNumberOfLines: numberOfLines)
        return textRect.inset(by: invertedContentInset)
    }
    
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInset))
    }
    
}
