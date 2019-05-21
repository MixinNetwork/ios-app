import UIKit

class BalanceInputAccessoryView: UIView {
    
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var balanceLabel: UILabel!
    
    @IBOutlet weak var contentBottomConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        if #available(iOS 11.0, *) { } else {
            bounds.size.height += 8
            contentBottomConstraint.constant = 8
        }
        button.setBackgroundImage(UIColor(displayP3RgbValue: 0xD3D5DA).image, for: .normal)
        button.setBackgroundImage(UIColor(displayP3RgbValue: 0xEBEDEF).image, for: .highlighted)
    }
    
}
