import UIKit

class BalanceInputAccessoryView: UIView {
    
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var balanceLabel: UILabel!
    
    @IBOutlet weak var contentBottomConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        button.setBackgroundImage(UIColor.clear.image, for: .normal)
        button.setBackgroundImage(R.color.keyboard_button_highlighted()!.image, for: .highlighted)
    }
    
}
