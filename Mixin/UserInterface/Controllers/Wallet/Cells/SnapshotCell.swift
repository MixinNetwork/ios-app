import UIKit
import MixinServices

protocol SnapshotCellDelegate: AnyObject {
    func walletSnapshotCellDidSelectIcon(_ cell: SnapshotCell)
}

final class SnapshotCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var pendingDepositProgressView: UIView!
    @IBOutlet weak var iconImageView: AvatarImageView!
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var amountLabel: InsetLabel!
    @IBOutlet weak var symbolLabel: UILabel!
    
    @IBOutlet weak var pendingDepositProgressConstraint: NSLayoutConstraint!
    
    weak var delegate: SnapshotCellDelegate?
    
    private weak var inscriptionIconView: InscriptionIconView?
    
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
                amountLabel.textColor = .priceFalling
            } else {
                amountLabel.textColor = .priceRising
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
            symbolLabel.text = token?.symbol ?? snapshot.tokenSymbol
            inscriptionIconView?.isHidden = true
        }
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

extension SnapshotCell {
    
    private class InscriptionIconView: UIView {
        
        var content: InscriptionContent? {
            didSet {
                switch content {
                case let .image(url):
                    imageView.contentMode = .scaleAspectFill
                    imageView.sd_setImage(with: url)
                    textContentView?.isHidden = true
                case let .text(collectionIconURL, textContentURL):
                    imageView.contentMode = .scaleToFill
                    imageView.image = R.image.collectible_text_background()
                    let contentView: TextInscriptionContentView
                    if let view = self.textContentView {
                        view.isHidden = false
                        contentView = view
                    } else {
                        contentView = TextInscriptionContentView(iconDimension: 22, spacing: 1)
                        contentView.label.numberOfLines = 1
                        contentView.label.font = .systemFont(ofSize: 6, weight: .semibold)
                        addSubview(contentView)
                        contentView.snp.makeConstraints { make in
                            let inset = UIEdgeInsets(top: 4, left: 6, bottom: 5, right: 6)
                            make.edges.equalToSuperview().inset(inset)
                        }
                        self.textContentView = contentView
                    }
                    contentView.reloadData(collectionIconURL: collectionIconURL,
                                           textContentURL: textContentURL)
                case .none:
                    imageView.contentMode = .scaleAspectFit
                    imageView.image = R.image.inscription_intaglio()
                    textContentView?.isHidden = true
                }
            }
        }
        
        private let imageView = UIImageView()
        
        private weak var textContentView: TextInscriptionContentView?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            loadSubview()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            loadSubview()
        }
        
        override func layoutSubviews() {
            if content == nil {
                imageView.frame.size = CGSize(width: bounds.width / 2, height: bounds.height / 2)
            } else {
                imageView.frame.size = CGSize(width: bounds.width, height: bounds.height)
            }
            imageView.center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        }
        
        func prepareForReuse() {
            imageView.sd_cancelCurrentImageLoad()
            textContentView?.prepareForReuse()
        }
        
        private func loadSubview() {
            backgroundColor = R.color.sticker_button_background_disabled()
            layer.cornerRadius = 12
            layer.masksToBounds = true
            imageView.contentMode = .scaleAspectFill
            addSubview(imageView)
        }
        
    }
    
}
