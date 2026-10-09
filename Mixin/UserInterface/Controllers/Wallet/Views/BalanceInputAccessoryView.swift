import UIKit

class BalanceInputAccessoryView: UIView {
    
    @IBOutlet weak var button: HighlightableButton!
    @IBOutlet weak var balanceLabel: UILabel!
    
    @IBOutlet weak var contentBottomConstraint: NSLayoutConstraint!
    
    override var intrinsicContentSize: CGSize {
        if #available(iOS 26, *) {
            return CGSize(width: UIView.noIntrinsicMetric, height: 52)
        } else {
            return CGSize(width: UIView.noIntrinsicMetric, height: 44)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = R.color.keyboard_background_14()
        button.highlightedColor = R.color.keyboard_balance_highlighted_14()
        if #available(iOS 26, *) {
            backgroundColor = .clear
            contentBottomConstraint.constant = 8
            if let container = button.superview {
                container.backgroundColor = R.color.keyboard_background_14()
                container.layer.cornerRadius = 18
                container.layer.masksToBounds = true
            }
        }
    }
    
}
