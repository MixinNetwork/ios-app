import UIKit
import MixinServices

class Web3TransactionCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var iconView: BadgeIconView!
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

        let defalutLayer = { [unowned self] in
            hideViews(amountLabel1, symbolLabel1, amountLabel2, symbolLabel2, priceLabel)
            subtitleLabel.text = ""
        }
        let isConfirmed = transaction.status == Web3Transaction.Web3TransactionStatus.confirmed.rawValue
        
        switch Web3Transaction.Web3TransactionType(rawValue: transaction.operationType) {
        case .receive:
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
                amountLabel1.textColor = isConfirmed ? .walletGreen : .walletGray
                subtitleLabel.text = Address.compactRepresentation(of: transaction.sender)
            } else {
                defalutLayer()
            }
        case .send:
            if let transfer = transaction.transfers.first {
                hideViews(amountLabel2, symbolLabel2)
                showViews(amountLabel1, symbolLabel1, priceLabel)
                
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

extension BadgeIconView {
    
    func setIcon(web3Transaction transaction: Web3Transaction) {
        switch transaction.operationType {
        case Web3Transaction.Web3TransactionType.send.rawValue:
            iconImageView.image = R.image.wallet.snapshot_withdrawal()
            isChainIconHidden = true
        case Web3Transaction.Web3TransactionType.receive.rawValue:
            iconImageView.image = R.image.wallet.snapshot_deposit()
            isChainIconHidden = true
        default:
            isChainIconHidden = false
            if let app = transaction.appMetadata {
                iconImageView.sd_setImage(with: URL(string: app.iconURL),
                                          placeholderImage: nil,
                                          context: assetIconContext)
                chainImageView.sd_setImage(with: URL(string: transaction.fee.iconURL), placeholderImage: nil, context: assetIconContext)
            } else {
                iconImageView.image = nil
                chainImageView.image = nil
            }
        }
    }
    
}
