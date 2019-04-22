import UIKit

class SearchTitleView: UIView {
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var cancelButton: UIButton!
    
    @IBOutlet weak var searchBoxLeadingConstraint: NSLayoutConstraint!
    
    override var intrinsicContentSize: CGSize {
        return UIView.layoutFittingExpandedSize
    }
    
}
