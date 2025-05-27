import UIKit

final class ComplexWeb3TransactionTableHeaderView: InfiniteTopView, Web3TransactionTableHeaderView {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var statusLabel: TransactionStatusLabel!
    
    @IBOutlet weak var contentStackViewBottomConstraint: NSLayoutConstraint!
    
    weak var actionView: PillActionView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentStackView.setCustomSpacing(19, after: iconView)
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 18, weight: .semibold),
            adjustForContentSize: true
        )
    }
    
}
