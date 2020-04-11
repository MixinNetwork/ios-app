import UIKit

class CirclesTableFooterView: UIView {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var button: UIButton!
    
    @IBOutlet weak var labelTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var buttonTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentViewHeightConstraint: NSLayoutConstraint!
    
    var showsHintLabel = false {
        didSet {
            contentViewHeightConstraint.priority = showsHintLabel ? .almostInexist : .almostRequired
        }
    }
    
}
