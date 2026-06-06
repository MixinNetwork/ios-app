import UIKit
import MixinServices

protocol SnapshotCellDelegate: AnyObject {
    func walletSnapshotCellDidSelectIcon(_ cell: SnapshotCell)
}

final class SnapshotCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var iconImageView: AvatarImageView!
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var amountLabel: InsetLabel!
    @IBOutlet weak var symbolLabel: UILabel!
    
    weak var delegate: SnapshotCellDelegate?
    
    private weak var inscriptionIconView: InscriptionIconView?
    private weak var progressLayer: CAGradientLayer?
    
    private var progress: CGFloat = 0
    
    override func awakeFromNib() {
        super.awakeFromNib()
        amountLabel.contentInset = UIEdgeInsets(top: 2, left: 0, bottom: 0, right: 0)
        amountLabel.setFont(scaledFor: .condensed(size: 19), adjustForContentSize: true)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.prepareForReuse()
        progress = 0
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutProgressLayer()
    }
    
    @IBAction func selectIconAction(_ sender: Any) {
        delegate?.walletSnapshotCellDidSelectIcon(self)
    }
    
    func render(snapshot: SafeSnapshotItem) {
        // Disable alpha animation for `progressLayer`
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer {
            CATransaction.commit()
        }
        
        switch SafeSnapshot.SnapshotType(rawValue: snapshot.type) {
        case .pending:
            iconImageView.imageView.contentMode = .center
            iconImageView.image = R.image.wallet.snapshot_deposit()
            if var finished = snapshot.confirmations, let total = snapshot.tokenConfirmations {
                finished = min(total, finished)
                progress = CGFloat(finished) / CGFloat(total)
                let progressLayer: CAGradientLayer
                if let layer = self.progressLayer {
                    layer.isHidden = false
                    progressLayer = layer
                } else {
                    let layer = CAGradientLayer()
                    layer.startPoint = CGPoint(x: 0, y: 0.5)
                    layer.endPoint = CGPoint(x: 1, y: 0.5)
                    layer.locations = [0, 1]
                    contentView.layer.insertSublayer(layer, at: 0)
                    self.progressLayer = layer
                    progressLayer = layer
                }
                progressLayer.colors = [
                    R.color.market_green()!.withAlphaComponent(progress == 1 ? 0.2 : 0).cgColor,
                    R.color.market_green()!.withAlphaComponent(0.2).cgColor,
                ]
                layoutProgressLayer()
                setTitle(R.string.localizable.pending_confirmations(finished, total))
            } else {
                progressLayer?.isHidden = true
                setTitle(snapshot.deposit?.sender)
            }
            amountLabel.textColor = R.color.text_tertiary()!
        default:
            progressLayer?.isHidden = true
            if let deposit = snapshot.deposit {
                iconImageView.imageView.contentMode = .center
                iconImageView.image = R.image.wallet.snapshot_deposit()
                setTitle(deposit.compactSender)
                updateAmountTitleColor(amount: snapshot.decimalAmount)
            } else if let withdrawal = snapshot.withdrawal {
                iconImageView.imageView.contentMode = .center
                iconImageView.image = R.image.wallet.snapshot_withdrawal()
                setTitle(withdrawal.compactReceiver)
                if withdrawal.hash.isEmpty {
                    amountLabel.textColor = R.color.text_tertiary()!
                } else {
                    updateAmountTitleColor(amount: snapshot.decimalAmount)
                }
            } else if let userID = snapshot.opponentUserID, let name = snapshot.opponentFullname, let url = snapshot.opponentAvatarURL {
                iconImageView.imageView.contentMode = .scaleAspectFill
                iconImageView.setImage(with: url, userId: userID, name: name)
                setTitle(snapshot.opponentFullname)
                updateAmountTitleColor(amount: snapshot.decimalAmount)
            } else {
                iconImageView.imageView.contentMode = .center
                iconImageView.image = R.image.wallet.snapshot_anonymous()
                setTitle(nil)
                updateAmountTitleColor(amount: snapshot.decimalAmount)
            }
        }
        if snapshot.isInscription {
            let amount: Decimal = snapshot.decimalAmount > 0 ? 1 : -1
            amountLabel.text = CurrencyFormatter.localizedString(from: amount, format: .precision, sign: .always)
            symbolLabel.isHidden = true
            let inscriptionIconView: InscriptionIconView
            if let view = self.inscriptionIconView {
                view.isHidden = false
                inscriptionIconView = view
            } else {
                inscriptionIconView = InscriptionIconView()
                contentStackView.addArrangedSubview(inscriptionIconView)
                inscriptionIconView.snp.makeConstraints { make in
                    make.width.height.equalTo(40).priority(.almostRequired)
                }
                self.inscriptionIconView = inscriptionIconView
            }
            inscriptionIconView.content = snapshot.inscriptionContent
        } else {
            amountLabel.text = CurrencyFormatter.localizedString(from: snapshot.decimalAmount, format: .precision, sign: .always)
            symbolLabel.isHidden = false
            symbolLabel.text = snapshot.tokenSymbol
            inscriptionIconView?.isHidden = true
        }
    }
    
    private func setTitle(_ title: String?) {
        if let title, !title.isEmpty {
            titleLabel.text = title
            titleLabel.textColor = R.color.text()
        } else {
            titleLabel.text = .notApplicable
            titleLabel.textColor = R.color.text_tertiary()!
        }
    }
    
    private func updateAmountTitleColor(amount: Decimal) {
        if amount < 0 {
            amountLabel.textColor = R.color.market_red()
        } else {
            amountLabel.textColor = R.color.market_green()
        }
    }
    
    private func layoutProgressLayer() {
        guard let progressLayer else {
            return
        }
        let iconTopLeft: CGPoint = iconImageView.convert(.zero, to: contentView)
        let progressLeft = iconTopLeft.x + iconImageView.frame.width / 2
        let fullWidth = contentView.bounds.width - progressLeft
        CATransaction.performWithoutAnimation {
            progressLayer.frame = CGRect(
                x: progressLeft + fullWidth * (1 - progress),
                y: iconTopLeft.y,
                width: fullWidth * progress,
                height: iconImageView.frame.height
            )
        }
    }
    
}
