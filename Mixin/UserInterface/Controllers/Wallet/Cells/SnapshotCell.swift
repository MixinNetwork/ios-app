import UIKit
import MixinServices

protocol SnapshotCellDelegate: AnyObject {
    func walletSnapshotCellDidSelectIcon(_ cell: SnapshotCell)
}

final class SnapshotCell: ModernSelectedBackgroundCell {
    
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
                setTitle(R.string.localizable.pending_confirmations(finished, total))
                pendingDepositProgressView.isHidden = false
                let multiplier = CGFloat(finished) / CGFloat(total)
                if abs(pendingDepositProgressConstraint.multiplier - multiplier) > 0.1 {
                    NSLayoutConstraint.deactivate([pendingDepositProgressConstraint])
                    pendingDepositProgressConstraint = pendingDepositProgressView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: multiplier)
                    NSLayoutConstraint.activate([pendingDepositProgressConstraint])
                }
            } else {
                pendingDepositProgressView.isHidden = true
                setTitle(snapshot.deposit?.sender)
            }
            amountLabel.textColor = R.color.text_tertiary()!
        default:
            if let deposit = snapshot.deposit {
                iconImageView.imageView.contentMode = .center
                iconImageView.image = R.image.wallet.snapshot_deposit()
                setTitle(deposit.compactSender)
            } else if let withdrawal = snapshot.withdrawal {
                iconImageView.imageView.contentMode = .center
                iconImageView.image = R.image.wallet.snapshot_withdrawal()
                setTitle(withdrawal.compactReceiver)
            } else if let userID = snapshot.opponentUserID, let name = snapshot.opponentFullname, let url = snapshot.opponentAvatarURL {
                iconImageView.imageView.contentMode = .scaleAspectFill
                iconImageView.setImage(with: url, userId: userID, name: name)
                setTitle(snapshot.opponentFullname)
            } else {
                iconImageView.imageView.contentMode = .center
                iconImageView.image = R.image.wallet.snapshot_anonymous()
                setTitle(nil)
            }
            pendingDepositProgressView.isHidden = true
            if snapshot.amount.hasMinusPrefix {
                amountLabel.textColor = .walletRed
            } else {
                amountLabel.textColor = .walletGreen
            }
        }
        amountLabel.text = CurrencyFormatter.localizedString(from: snapshot.decimalAmount, format: .precision, sign: .always)
        symbolLabel.text = token?.symbol ?? snapshot.tokenSymbol
    }
    
    private func setTitle(_ title: String?) {
        if let title, !title.isEmpty {
            titleLabel.text = title
            titleLabel.textColor = R.color.text()
        } else {
            titleLabel.text = notApplicable
            titleLabel.textColor = R.color.text_tertiary()!
        }
    }
    
}
