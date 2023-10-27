import UIKit
import MixinServices

protocol SnapshotCellDelegate: AnyObject {
    func walletSnapshotCellDidSelectIcon(_ cell: SnapshotCell)
}

class SnapshotCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var pendingDepositProgressView: UIView!
    @IBOutlet weak var iconImageView: AvatarImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var amountLabel: InsetLabel!
    @IBOutlet weak var symbolLabel: UILabel!
    
    @IBOutlet weak var pendingDepositProgressConstraint: NSLayoutConstraint!
    
    weak var delegate: SnapshotCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        amountLabel.contentInset = UIEdgeInsets(top: 2, left: 0, bottom: 0, right: 0)
        amountLabel.setFont(scaledFor: .condensed(size: 19), adjustForContentSize: true)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.prepareForReuse()
    }
    
    @IBAction func selectIconAction(_ sender: Any) {
        delegate?.walletSnapshotCellDidSelectIcon(self)
    }
    
    func render(snapshot: SafeSnapshotItem, asset: TokenItem? = nil) {
        if let userID = snapshot.opponentUserID, let name = snapshot.opponentFullname, let url = snapshot.opponentAvatarURL {
            iconImageView.setImage(with: url, userId: userID, name: name)
        } else {
            iconImageView.image = R.image.wallet.ic_transaction_external()
        }
        switch snapshot.type {
        case SnapshotType.deposit.rawValue:
            amountLabel.textColor = .walletGreen
            titleLabel.text = R.string.localizable.deposit()
        case SnapshotType.transfer.rawValue:
            if snapshot.amount.hasMinusPrefix {
                amountLabel.textColor = .walletRed
            } else {
                amountLabel.textColor = .walletGreen
            }
            titleLabel.text = R.string.localizable.transfer()
        case SnapshotType.raw.rawValue:
            if snapshot.amount.hasMinusPrefix {
                amountLabel.textColor = .walletRed
            } else {
                amountLabel.textColor = .walletGreen
            }
            titleLabel.text = R.string.localizable.raw()
        case SnapshotType.withdrawal.rawValue:
            amountLabel.textColor = .walletRed
            titleLabel.text = R.string.localizable.withdrawal()
        case SnapshotType.fee.rawValue:
            amountLabel.textColor = .walletRed
            titleLabel.text = R.string.localizable.fee()
        case SnapshotType.rebate.rawValue:
            amountLabel.textColor = .walletGreen
            titleLabel.text = R.string.localizable.rebate()
        case SnapshotType.pendingDeposit.rawValue:
            amountLabel.textColor = .walletGray
//            if let finished = snapshot.confirmations, let total = asset?.confirmations {
//                titleLabel.text = R.string.localizable.pending_confirmations(finished, total)
//            } else {
//                titleLabel.text = nil
//            }
        default:
            break
        }
        amountLabel.text = CurrencyFormatter.localizedString(from: snapshot.amount, format: .precision, sign: .always)
        symbolLabel.text = asset?.symbol ?? snapshot.assetSymbol
//        if snapshot.type == SnapshotType.pendingDeposit.rawValue, let finished = snapshot.confirmations, let total = asset?.confirmations {
//            pendingDepositProgressView.isHidden = false
//            let multiplier = CGFloat(finished) / CGFloat(total)
//            if abs(pendingDepositProgressConstraint.multiplier - multiplier) > 0.1 {
//                NSLayoutConstraint.deactivate([pendingDepositProgressConstraint])
//                pendingDepositProgressConstraint = pendingDepositProgressView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: multiplier)
//                NSLayoutConstraint.activate([pendingDepositProgressConstraint])
//            }
//        } else {
        pendingDepositProgressView.isHidden = true
//        }
    }
    
}
