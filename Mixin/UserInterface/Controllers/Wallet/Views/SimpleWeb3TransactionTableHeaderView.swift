import UIKit

final class SimpleWeb3TransactionTableHeaderView: InfiniteTopView {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconView: BadgeIconView!
    @IBOutlet weak var amountStackView: UIStackView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var symbolLabel: InsetLabel!
    @IBOutlet weak var statusLabel: Web3TransactionStatusLabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentStackView.setCustomSpacing(10, after: iconView)
        iconView.badgeIconDiameter = 20
        iconView.badgeOutlineWidth = 1
    }
    
}
