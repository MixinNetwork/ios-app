import UIKit

final class SimpleWeb3TransactionTableHeaderView: InfiniteTopView, Web3TransactionTableHeaderView {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconView: BadgeIconView!
    @IBOutlet weak var amountStackView: UIStackView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var symbolLabel: InsetLabel!
    @IBOutlet weak var statusLabel: Web3TransactionStatusLabel!
    
    @IBOutlet weak var contentStackViewBottomConstraint: NSLayoutConstraint!
    
    weak var actionView: PillActionView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentStackView.setCustomSpacing(10, after: iconView)
        contentStackView.setCustomSpacing(20, after: statusLabel)
        iconView.badgeIconDiameter = 20
        iconView.badgeOutlineWidth = 1
    }
    
}
