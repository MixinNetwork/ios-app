import UIKit

final class ComplexWeb3TransactionTableHeaderView: InfiniteTopView {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var statusLabel: Web3TransactionStatusLabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentStackView.setCustomSpacing(19, after: iconView)
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 18, weight: .semibold),
            adjustForContentSize: true
        )
    }
    
}
