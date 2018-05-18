import UIKit

class InsetLabel: UILabel {

    var contentInset = UIEdgeInsets(top: 1, left: 6, bottom: 1, right: 6) {
        didSet {
            invertedContentInset = UIEdgeInsets(top: -contentInset.top,
                                                left: -contentInset.left,
                                                bottom: -contentInset.bottom,
                                                right: -contentInset.right)
            invalidateIntrinsicContentSize()
        }
    }
    
    private var invertedContentInset = UIEdgeInsets(top: -1, left: -6, bottom: -1, right: -6)

    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let layoutBounds = UIEdgeInsetsInsetRect(bounds, contentInset)
        let textRect = super.textRect(forBounds: layoutBounds, limitedToNumberOfLines: numberOfLines)
        return UIEdgeInsetsInsetRect(textRect, invertedContentInset)
    }
    
    override func drawText(in rect: CGRect) {
        super.drawText(in: UIEdgeInsetsInsetRect(rect, contentInset))
    }

}
