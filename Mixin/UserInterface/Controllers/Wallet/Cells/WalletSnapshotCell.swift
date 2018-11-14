import UIKit

class WalletSnapshotCell: UITableViewCell {
    
    static let height: CGFloat = 60
    
    @IBOutlet weak var shadowSafeContainerView: UIView!
    @IBOutlet weak var pendingDepositProgressView: UIView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var bottomShadowImageView: UIImageView!
    
    @IBOutlet weak var pendingDepositProgressConstraint: NSLayoutConstraint!
    
    func render(snapshot: SnapshotItem, asset: AssetItem) {
        iconImageView.sd_setImage(with: nil, completed: nil)
        switch snapshot.type {
        case SnapshotType.deposit.rawValue, SnapshotType.pendingDeposit.rawValue:
            iconImageView.image = UIImage(named: "Wallet/ic_deposit")
        case SnapshotType.withdrawal.rawValue, SnapshotType.fee.rawValue, SnapshotType.rebate.rawValue:
            iconImageView.image = UIImage(named: "Wallet/ic_withdrawal")
        case SnapshotType.transfer.rawValue:
            if let iconUrl = snapshot.opponentUserAvatarUrl, let url = URL(string: iconUrl) {
                iconImageView.sd_setImage(with: url, placeholderImage: #imageLiteral(resourceName: "ic_place_holder"))
            }
        default:
            break
        }
        switch snapshot.type {
        case SnapshotType.deposit.rawValue:
            amountLabel.textColor = .walletGreen
            titleLabel.text = Localized.TRANSACTION_TYPE_DEPOSIT
        case SnapshotType.transfer.rawValue:
            if snapshot.amount.hasMinusPrefix {
                amountLabel.textColor = .walletRed
            } else {
                amountLabel.textColor = .walletGreen
            }
            titleLabel.text = Localized.TRANSACTION_TYPE_TRANSFER
        case SnapshotType.withdrawal.rawValue:
            amountLabel.textColor = .walletRed
            titleLabel.text = Localized.TRANSACTION_TYPE_WITHDRAWAL
        case SnapshotType.fee.rawValue:
            amountLabel.textColor = .walletRed
            titleLabel.text = Localized.TRANSACTION_TYPE_FEE
        case SnapshotType.rebate.rawValue:
            amountLabel.textColor = .walletGreen
            titleLabel.text = Localized.TRANSACTION_TYPE_REBATE
        case SnapshotType.pendingDeposit.rawValue:
            amountLabel.textColor = .walletGray
            if let confirmations = snapshot.confirmations {
                titleLabel.text = Localized.PENDING_DEPOSIT_CONFIRMATION(numerator: confirmations,
                                                                         denominator: asset.confirmations)
            } else {
                titleLabel.text = nil
            }
        default:
            break
        }
        amountLabel.text = CurrencyFormatter.localizedString(from: snapshot.amount, format: .precision, sign: .always)
        if snapshot.type == SnapshotType.pendingDeposit.rawValue, let confirmations = snapshot.confirmations {
            pendingDepositProgressView.isHidden = false
            let multiplier = CGFloat(confirmations) / CGFloat(asset.confirmations)
            if abs(pendingDepositProgressConstraint.multiplier - multiplier) > 0.1 {
                NSLayoutConstraint.deactivate([pendingDepositProgressConstraint])
                pendingDepositProgressConstraint = pendingDepositProgressView.widthAnchor.constraint(equalTo: shadowSafeContainerView.widthAnchor, multiplier: multiplier)
                NSLayoutConstraint.activate([pendingDepositProgressConstraint])
            }
        } else {
            pendingDepositProgressView.isHidden = true
        }
    }
    
}
