import UIKit

protocol SnapshotCellDelegate: class {
    func walletSnapshotCellDidSelectIcon(_ cell: SnapshotCell)
}

class SnapshotCell: UITableViewCell {
    
    static let height: CGFloat = 60
    
    @IBOutlet weak var shadowSafeContainerView: UIView!
    @IBOutlet weak var pendingDepositProgressView: UIView!
    @IBOutlet weak var iconImageView: AvatarImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var bottomShadowImageView: UIImageView!
    @IBOutlet weak var selectionView: RoundCornerSelectionView!
    @IBOutlet weak var separatorLineView: UIView!
    
    @IBOutlet weak var pendingDepositProgressConstraint: NSLayoutConstraint!
    
    weak var delegate: SnapshotCellDelegate?
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        selectionView.setHighlighted(selected, animated: animated)
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        selectionView.setHighlighted(highlighted, animated: animated)
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
                pendingDepositProgressConstraint = pendingDepositProgressView.widthAnchor.constraint(equalTo: shadowSafeContainerView.widthAnchor, multiplier: multiplier)
                NSLayoutConstraint.activate([pendingDepositProgressConstraint])
            }
        } else {
            pendingDepositProgressView.isHidden = true
        }
    }
    
    func renderDecorationViews(indexPath: IndexPath, models: [[Any]]) {
        let lastSection = models.count - 1
        let lastIndexPath = IndexPath(row: models[lastSection].count - 1, section: lastSection)
        if indexPath == lastIndexPath {
            bottomShadowImageView.isHidden = false
            selectionView.roundingCorners = [.bottomLeft, .bottomRight]
        } else {
            bottomShadowImageView.isHidden = true
            selectionView.roundingCorners = []
        }
        separatorLineView.isHidden = models[indexPath.section].count == 1
            || indexPath.row == models[indexPath.section].count - 1
    }
    
}
