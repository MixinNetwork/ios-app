import UIKit

class BalanceInputAccessoryView: UIView {
    
    @IBOutlet weak var button: HighlightableButton!
    @IBOutlet weak var balanceLabel: UILabel!
    
    @IBOutlet weak var contentBottomConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = R.color.keyboard_background_14()
        button.highlightedColor = R.color.keyboard_balance_highlighted_14()
    }
    
}
