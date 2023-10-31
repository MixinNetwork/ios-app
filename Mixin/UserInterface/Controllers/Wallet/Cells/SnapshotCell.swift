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
        if let userID = snapshot.opponentUserID, let name = snapshot.opponentFullname, let url = snapshot.opponentAvatarURL {
            iconImageView.setImage(with: url, userId: userID, name: name)
        } else {
            iconImageView.image = R.image.wallet.ic_transaction_external()
        }
        switch SafeSnapshot.SnapshotType(rawValue: snapshot.type) {
        case .pending:
            amountLabel.textColor = .walletGray
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
                titleLabel.text = nil
            }
        default:
            if snapshot.amount.hasMinusPrefix {
                amountLabel.textColor = .walletRed
            } else {
                amountLabel.textColor = .walletGreen
            }
            if snapshot.opponentID.isEmpty {
                titleLabel.text = R.string.localizable.deposit()
            } else {
                titleLabel.text = snapshot.opponentFullname
            }
            pendingDepositProgressView.isHidden = true
        }
        amountLabel.text = CurrencyFormatter.localizedString(from: snapshot.amount, format: .precision, sign: .always)
        symbolLabel.text = token?.symbol ?? snapshot.assetSymbol
    }
    
}
