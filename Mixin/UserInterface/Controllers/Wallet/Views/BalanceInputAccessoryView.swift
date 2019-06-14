import UIKit

class BalanceInputAccessoryView: UIView {
    
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var balanceLabel: UILabel!
    
    @IBOutlet weak var contentBottomConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        button.setBackgroundImage(UIColor(displayP3RgbValue: 0xD3D5DA).image, for: .normal)
        button.setBackgroundImage(UIColor(displayP3RgbValue: 0xEBEDEF).image, for: .highlighted)
    }
    
}
