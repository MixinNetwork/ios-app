import UIKit

protocol SnapshotCellDelegate: class {
    func walletSnapshotCellDidSelectIcon(_ cell: SnapshotCell)
}

class SnapshotCell: UITableViewCell {
    
    static let height: CGFloat = 50
    
    @IBOutlet weak var pendingDepositProgressView: UIView!
    @IBOutlet weak var iconImageView: AvatarImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var amountLabel: InsetLabel!
    @IBOutlet weak var symbolLabel: UILabel!
    
    @IBOutlet weak var pendingDepositProgressConstraint: NSLayoutConstraint!
    
    weak var delegate: SnapshotCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView(frame: bounds)
        selectedBackgroundView!.backgroundColor = .modernCellSelection
        amountLabel.contentInset = UIEdgeInsets(top: 2, left: 0, bottom: 0, right: 0)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.sd_cancelCurrentImageLoad()
        iconImageView.image = nil
        iconImageView.titleLabel.text = nil
    }
    
    @IBAction func selectIconAction(_ sender: Any) {
        delegate?.walletSnapshotCellDidSelectIcon(self)
    }
    
    func render(snapshot: SnapshotItem, asset: AssetItem? = nil) {
        switch snapshot.type {
        case SnapshotType.deposit.rawValue, SnapshotType.pendingDeposit.rawValue:
            iconImageView.image = UIImage(named: "Wallet/ic_deposit")
        case SnapshotType.withdrawal.rawValue, SnapshotType.fee.rawValue, SnapshotType.rebate.rawValue:
            iconImageView.image = UIImage(named: "Wallet/ic_withdrawal")
        case SnapshotType.transfer.rawValue:
            if let iconUrl = snapshot.opponentUserAvatarUrl, let identityNumber = snapshot.opponentUserIdentityNumber, let name = snapshot.opponentUserFullName {
                iconImageView.setImage(with: iconUrl, identityNumber: identityNumber, name: name)
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
            if let finished = snapshot.confirmations, let total = asset?.confirmations {
                titleLabel.text = Localized.PENDING_DEPOSIT_CONFIRMATION(numerator: finished,
                                                                         denominator: total)
            } else {
                titleLabel.text = nil
            }
        default:
            break
        }
        amountLabel.text = CurrencyFormatter.localizedString(from: snapshot.amount, format: .precision, sign: .always)
        if snapshot.type == SnapshotType.pendingDeposit.rawValue, let finished = snapshot.confirmations, let total = asset?.confirmations {
            pendingDepositProgressView.isHidden = false
            let multiplier = CGFloat(finished) / CGFloat(total)
            if abs(pendingDepositProgressConstraint.multiplier - multiplier) > 0.1 {
                NSLayoutConstraint.deactivate([pendingDepositProgressConstraint])
                pendingDepositProgressConstraint = pendingDepositProgressView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: multiplier)
                NSLayoutConstraint.activate([pendingDepositProgressConstraint])
            }
        } else {
            pendingDepositProgressView.isHidden = true
        }
        symbolLabel.text = snapshot.assetSymbol
    }
    
}
