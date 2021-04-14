import UIKit

class BalanceInputAccessoryView: UIView {
    
    @IBOutlet weak var button: HighlightableButton!
    @IBOutlet weak var balanceLabel: UILabel!
    
    @IBOutlet weak var contentBottomConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        if #available(iOS 14.0, *) {
            backgroundColor = R.color.keyboard_background_14()
            button.highlightedColor = R.color.keyboard_balance_highlighted_14()
        } else {
            backgroundColor = R.color.keyboard_background_13()
            button.highlightedColor = R.color.keyboard_balance_highlighted_13()
        }
    }
    
}
