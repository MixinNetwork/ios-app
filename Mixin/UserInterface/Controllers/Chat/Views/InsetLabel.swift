import UIKit

class InsetLabel: UILabel {

    var contentInset = UIEdgeInsets(top: 1, left: 6, bottom: 1, right: 6)

    override var intrinsicContentSize: CGSize {
        let intrinsicContentSize = super.intrinsicContentSize
        guard self.text?.count ?? 0 > 1 else {
            return CGSize(width: intrinsicContentSize.width + 2,
                          height: intrinsicContentSize.height + 2)
        }
        return CGSize(width: intrinsicContentSize.width + contentInset.left + contentInset.right,
                      height: intrinsicContentSize.height + contentInset.top + contentInset.bottom)
    }
    
}
