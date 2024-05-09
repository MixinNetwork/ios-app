import UIKit
import MixinServices

class Web3TransactionCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var iconView: AssetIconView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var amountLabel1: UILabel!
    @IBOutlet weak var symbolLabel1: UILabel!
    @IBOutlet weak var amountLabel2: UILabel!
    @IBOutlet weak var symbolLabel2: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
    
    func render(transaction: Web3Transaction) {
        iconView.setIcon(web3Transaction: transaction)
        titleLabel.text = transaction.localizedTransactionType
        
        func renderAsDefault() {
            hide(amountLabel1, symbolLabel1, amountLabel2, symbolLabel2, priceLabel)
            subtitleLabel.text = ""
        }
        let isConfirmed = transaction.status == Web3Transaction.Status.confirmed.rawValue
        
        switch Web3Transaction.TransactionType(rawValue: transaction.operationType) {
        case .receive:
            if let transfer = transaction.transfers.first {
                hide(amountLabel2, symbolLabel2)
                show(amountLabel1, symbolLabel1, priceLabel)
                
                amountLabel1.text = CurrencyFormatter.localizedString(from: transfer.amount, format: .precision, sign: .always)
                symbolLabel1.text = transfer.symbol
                priceLabel.text = if transfer.decimalUSDPrice.isZero {
                    R.string.localizable.na()
                } else {
                    transfer.localizedFiatMoneyAmount
                }
                amountLabel1.textColor = isConfirmed ? .walletGreen : .walletGray
                subtitleLabel.text = Address.compactRepresentation(of: transaction.sender)
            } else {
                renderAsDefault()
            }
        case .send:
            if let transfer = transaction.transfers.first {
                hide(amountLabel2, symbolLabel2)
                show(amountLabel1, symbolLabel1, priceLabel)
                
                amountLabel1.text = CurrencyFormatter.localizedString(from: "-\(transfer.amount)", format: .precision, sign: .never)
                symbolLabel1.text = transfer.symbol
                priceLabel.text = if transfer.decimalUSDPrice.isZero {
                    R.string.localizable.na()
                } else {
                    transfer.localizedFiatMoneyAmount
                }
                amountLabel1.textColor = isConfirmed ? .walletRed : .walletGray
                subtitleLabel.text = Address.compactRepresentation(of: transaction.receiver)
            } else {
                renderAsDefault()
            }
        case .trade:
            let inTransfer = transaction.transfers.first { transfer in
                transfer.direction == Web3Transaction.Web3Transfer.Direction.in.rawValue
            }
            let outTransfer = transaction.transfers.first { transfer in
                transfer.direction == Web3Transaction.Web3Transfer.Direction.out.rawValue
            }
            if let inTransfer, let outTransfer {
                hide(priceLabel)
                show(amountLabel1, symbolLabel1, amountLabel2, symbolLabel2)
                
                subtitleLabel.text = "\(inTransfer.symbol) -> \(outTransfer.symbol)"
                amountLabel1.text = CurrencyFormatter.localizedString(from: inTransfer.amount, format: .precision, sign: .always)
                symbolLabel1.text = inTransfer.symbol
                amountLabel1.textColor = isConfirmed ? .walletGreen : .walletGray
                
                amountLabel2.text = CurrencyFormatter.localizedString(from: "-\(outTransfer.amount)", format: .precision, sign: .always)
                symbolLabel2.text = outTransfer.symbol
                amountLabel2.textColor = isConfirmed ? .walletRed : .walletGray
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
