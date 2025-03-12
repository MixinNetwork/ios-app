import UIKit
import MixinServices

final class Web3TransactionHeaderView: InfiniteTopView {
    
    @IBOutlet weak var iconView: BadgeIconView!
    @IBOutlet weak var titleLabel: InsetLabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.contentInset = UIEdgeInsets(top: 1, left: 6, bottom: 1, right: 6)
    }
    
    func render(transaction: Web3Transaction) {
        titleLabel.text = transaction.localizedTransactionType
        iconView.setIcon(web3Transaction: transaction)
        // TODO: The content
    }
    
}
