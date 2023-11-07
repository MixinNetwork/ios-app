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
    
    func render(snapshot: SafeSnapshotItem, token: TokenItem? = nil) {
        switch SafeSnapshot.SnapshotType(rawValue: snapshot.type) {
        case .pending:
            iconImageView.imageView.contentMode = .center
            iconImageView.image = R.image.wallet.snapshot_deposit()
            if let finished = snapshot.confirmations, let total = token?.confirmations {
                titleLabel.text = R.string.localizable.pending_confirmations(finished, total)
                pendingDepositProgressView.isHidden = false
                let multiplier = CGFloat(finished) / CGFloat(total)
                if abs(pendingDepositProgressConstraint.multiplier - multiplier) > 0.1 {
                    NSLayoutConstraint.deactivate([pendingDepositProgressConstraint])
                    pendingDepositProgressConstraint = pendingDepositProgressView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: multiplier)
                    NSLayoutConstraint.activate([pendingDepositProgressConstraint])
                }
            } else {
                pendingDepositProgressView.isHidden = true
                titleLabel.text = snapshot.compactTransactionHash
            }
            titleLabel.textColor = R.color.text()
            amountLabel.textColor = .walletGray
        default:
            if snapshot.deposit != nil {
                iconImageView.imageView.contentMode = .center
                iconImageView.image = R.image.wallet.snapshot_deposit()
                titleLabel.text = snapshot.compactTransactionHash
                titleLabel.textColor = R.color.text()
            } else if snapshot.withdrawal != nil {
                iconImageView.imageView.contentMode = .center
                iconImageView.image = R.image.wallet.snapshot_withdrawal()
                titleLabel.text = snapshot.compactTransactionHash
                titleLabel.textColor = R.color.text()
            } else if let userID = snapshot.opponentUserID, let name = snapshot.opponentFullname, let url = snapshot.opponentAvatarURL {
                iconImageView.imageView.contentMode = .scaleAspectFill
                iconImageView.setImage(with: url, userId: userID, name: name)
                titleLabel.text = snapshot.opponentFullname
                titleLabel.textColor = R.color.text()
            } else {
                iconImageView.imageView.contentMode = .center
                iconImageView.image = R.image.wallet.snapshot_anonymous()
                titleLabel.text = "N/A"
                titleLabel.textColor = R.color.text_accessory()
            }
            pendingDepositProgressView.isHidden = true
            if snapshot.amount.hasMinusPrefix {
                amountLabel.textColor = .walletRed
            } else {
                amountLabel.textColor = .walletGreen
            }
        }
        amountLabel.text = CurrencyFormatter.localizedString(from: snapshot.amount, format: .precision, sign: .always)
        symbolLabel.text = token?.symbol ?? snapshot.tokenSymbol
    }
    
}
