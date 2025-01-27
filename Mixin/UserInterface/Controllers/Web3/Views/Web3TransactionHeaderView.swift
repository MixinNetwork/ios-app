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
        switch Web3Transaction.TransactionType(rawValue: transaction.operationType) {
        case .receive, .send:
            if let transfer = transaction.transfers.first {
                let amountLocalized = CurrencyFormatter.localizedString(from: transfer.amount, format: .precision, sign: .never) ?? transfer.amount
                subtitleLabel.text = "\(amountLocalized) \(transfer.symbol)"
            } else {
                subtitleLabel.text = ""
            }
        case .trade:
            let inTransfer = transaction.transfers.first { transfer in
                transfer.direction == Web3Transaction.Transfer.Direction.in.rawValue
            }
            let outTransfer = transaction.transfers.first { transfer in
                transfer.direction == Web3Transaction.Transfer.Direction.out.rawValue
            }
            if let inTransfer, let outTransfer {
                let inAmountLocalized = CurrencyFormatter.localizedString(from: inTransfer.amount, format: .precision, sign: .never) ?? inTransfer.amount
                let outAmountLocalized = CurrencyFormatter.localizedString(from: outTransfer.amount, format: .precision, sign: .never) ?? outTransfer.amount
                subtitleLabel.text = "\(inAmountLocalized) \(inTransfer.symbol) -> \(outAmountLocalized) \(outTransfer.symbol)"
            } else {
                subtitleLabel.text = ""
            }
        default:
            subtitleLabel.text = ""
        }
    }
    
}
