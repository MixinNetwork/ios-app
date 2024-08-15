import UIKit
import MixinServices

class Web3TransactionCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var iconView: BadgeIconView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var upperAmountLabel: UILabel!
    @IBOutlet weak var upperSymbolLabel: UILabel!
    @IBOutlet weak var lowerAmountLabel: UILabel!
    @IBOutlet weak var lowerSymbolLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
    
    func render(transaction: Web3Transaction) {
        iconView.setIcon(web3Transaction: transaction)
        titleLabel.text = transaction.localizedTransactionType
        
        func renderAsDefault() {
            hide(upperAmountLabel, upperSymbolLabel, lowerAmountLabel, lowerSymbolLabel, priceLabel)
            subtitleLabel.text = ""
        }
        let isConfirmed = transaction.status == Web3Transaction.Status.confirmed.rawValue
        
        switch Web3Transaction.TransactionType(rawValue: transaction.operationType) {
        case .receive:
            if let transfer = transaction.transfers.first {
                hide(lowerAmountLabel, lowerSymbolLabel)
                show(upperAmountLabel, upperSymbolLabel, priceLabel)
                
                upperAmountLabel.text = CurrencyFormatter.localizedString(from: transfer.amount, format: .precision, sign: .always)
                upperSymbolLabel.text = transfer.symbol
                priceLabel.text = if transfer.decimalUSDPrice.isZero {
                    R.string.localizable.na()
                } else {
                    transfer.localizedFiatMoneyAmount
                }
                upperAmountLabel.textColor = isConfirmed ? .priceRising : .walletGray
                subtitleLabel.text = Address.compactRepresentation(of: transaction.sender)
            } else {
                renderAsDefault()
            }
        case .send:
            if let transfer = transaction.transfers.first {
                hide(lowerAmountLabel, lowerSymbolLabel)
                show(upperAmountLabel, upperSymbolLabel, priceLabel)
                
                upperAmountLabel.text = CurrencyFormatter.localizedString(from: -transfer.decimalAmount, format: .precision, sign: .always)
                upperSymbolLabel.text = transfer.symbol
                priceLabel.text = if transfer.decimalUSDPrice.isZero {
                    R.string.localizable.na()
                } else {
                    transfer.localizedFiatMoneyAmount
                }
                upperAmountLabel.textColor = isConfirmed ? .priceFalling : .walletGray
                subtitleLabel.text = Address.compactRepresentation(of: transaction.receiver)
            } else {
                renderAsDefault()
            }
        case .trade:
            let inTransfer = transaction.transfers.first { transfer in
                transfer.direction == Web3Transaction.Transfer.Direction.in.rawValue
            }
            let outTransfer = transaction.transfers.first { transfer in
                transfer.direction == Web3Transaction.Transfer.Direction.out.rawValue
            }
            if let inTransfer, let outTransfer {
                hide(priceLabel)
                show(upperAmountLabel, upperSymbolLabel, lowerAmountLabel, lowerSymbolLabel)
                
                subtitleLabel.text = "\(inTransfer.symbol) -> \(outTransfer.symbol)"
                upperAmountLabel.text = CurrencyFormatter.localizedString(from: inTransfer.amount, format: .precision, sign: .always)
                upperSymbolLabel.text = inTransfer.symbol
                upperAmountLabel.textColor = isConfirmed ? .priceRising : .walletGray
                
                lowerAmountLabel.text = CurrencyFormatter.localizedString(from: -outTransfer.decimalAmount, format: .precision, sign: .always)
                lowerSymbolLabel.text = outTransfer.symbol
                lowerAmountLabel.textColor = isConfirmed ? .priceFalling : .walletGray
            } else {
                renderAsDefault()
            }
        default:
            renderAsDefault()
        }
    }
    
    private func hide(_ views: UIView...) {
        views.forEach({ $0.isHidden = true })
    }
    
    private func show(_ views: UIView...) {
        views.forEach({ $0.isHidden = false })
    }
    
}
