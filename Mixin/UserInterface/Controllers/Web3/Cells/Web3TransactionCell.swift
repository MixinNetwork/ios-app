import UIKit
import MixinServices

class Web3TransactionCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var iconView: Web3TransactionIconView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var amountLabel1: UILabel!
    @IBOutlet weak var symbolLabel1: UILabel!
    @IBOutlet weak var amountLabel2: UILabel!
    @IBOutlet weak var symbolLabel2: UILabel!
    
    @IBOutlet weak var priceLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView(frame: bounds)
        selectedBackgroundView!.backgroundColor = .selectionBackground
        
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
        
    func render(transaction: Web3Transaction) {
        iconView.setIcon(web3Transaction: transaction)
        titleLabel.text = transaction.operationType.capitalized

        let defalutLayer = { [unowned self] in
            hideViews(amountLabel1, symbolLabel1, amountLabel2, symbolLabel2, priceLabel)
            subtitleLabel.text = ""
        }
        let isConfirmed = transaction.status == Web3Transaction.Web3TransactionStatus.confirmed.rawValue
        
        switch Web3Transaction.Web3TransactionType(rawValue: transaction.operationType) {
        case .receive, .send:
            if let transfer = transaction.transfers.first {
                hideViews(amountLabel2, symbolLabel2)
                showViews(amountLabel1, symbolLabel1, priceLabel)
                
                amountLabel1.text = CurrencyFormatter.localizedString(from: transfer.amount, format: .precision, sign: .always)
                symbolLabel1.text = transfer.symbol
                priceLabel.text = if transfer.decimalUSDPrice.isZero {
                    R.string.localizable.na()
                } else {
                    transfer.localizedFiatMoneyAmount
                }
                
                if isConfirmed {
                    if transfer.amount.hasMinusPrefix {
                        amountLabel1.textColor = .walletRed
                    } else {
                        amountLabel1.textColor = .walletGreen
                    }
                } else {
                    amountLabel1.textColor = .walletGray
                }
                
                subtitleLabel.text = Address.compactRepresentation(of: transfer.sender)
            } else {
                defalutLayer()
            }
        case .trade:
            if let inTransfer = transaction.transfers.first(where: { $0.direction == Web3Transaction.Web3Transfer.Direction.in.rawValue }), let outTransfer = transaction.transfers.first(where: { $0.direction == Web3Transaction.Web3Transfer.Direction.out.rawValue }) {
                hideViews(priceLabel)
                showViews(amountLabel1, symbolLabel1, amountLabel2, symbolLabel2)
                
                subtitleLabel.text = "\(inTransfer.symbol) -> \(outTransfer.symbol)"
                amountLabel1.text = CurrencyFormatter.localizedString(from: inTransfer.amount, format: .precision, sign: .always)
                symbolLabel1.text = inTransfer.symbol
                amountLabel1.textColor = isConfirmed ? .walletGreen : .walletGray
                
                amountLabel2.text = CurrencyFormatter.localizedString(from: "-\(outTransfer.amount)", format: .precision, sign: .always)
                symbolLabel2.text = outTransfer.symbol
                amountLabel2.textColor = isConfirmed ? .walletRed : .walletGray
            } else {
                defalutLayer()
            }
        default:
            defalutLayer()
        }
    }
    
    private func hideViews(_ views: UIView...) {
        views.forEach({ $0.isHidden = true })
    }
    
    private func showViews(_ views: UIView...) {
        views.forEach({ $0.isHidden = false })
    }
}
