import UIKit
import MixinServices

final class TransactionCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func transactionCellDidSelectIcon(_ cell: TransactionCell)
    }
    
    @IBOutlet weak var iconView: AvatarImageView!
    @IBOutlet weak var iconButton: UIButton!
    @IBOutlet weak var statusWrapperView: UIView!
    @IBOutlet weak var statusImageView: UIImageView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var assetChangeStackView: UIStackView!
    
    weak var delegate: Delegate?
    
    private weak var badReputationImageView: UIImageView?
    private weak var inscriptionIconView: InscriptionIconView?
    private weak var progressLayer: CAGradientLayer?
    
    private var progress: CGFloat = 0
    
    private var rowViews: [RowStackView] = []
    
    override func awakeFromNib() {
        super.awakeFromNib()
        statusWrapperView.layer.cornerRadius = 7
        statusWrapperView.layer.masksToBounds = true
        statusImageView.layer.cornerRadius = 6
        statusImageView.layer.masksToBounds = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
        progress = 0
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutProgressLayer()
    }
    
    @IBAction func reportIconSelection(_ sender: Any) {
        delegate?.transactionCellDidSelectIcon(self)
    }
    
    func load(transaction: Web3Transaction, symbols: [String: String]) {
        switch transaction.transactionType.knownCase {
        case .transferIn:
            iconView.image = R.image.wallet.snapshot_deposit()
        case .transferOut:
            iconView.image = R.image.wallet.snapshot_withdrawal()
        case .swap:
            iconView.image = R.image.transaction_type_swap()
        case .approval:
            iconView.image = R.image.transaction_type_approval()
        case .unknown, .none:
            iconView.image = R.image.transaction_type_unknown()
        }
        iconButton.isUserInteractionEnabled = false
        switch transaction.status {
        case .pending:
            statusImageView.image = R.image.transaction_badge_pending()
        case .success:
            statusImageView.image = R.image.transaction_badge_success()
        case .failed, .notFound:
            statusImageView.image = R.image.transaction_badge_failed()
        }
        statusWrapperView.isHidden = false
        
        if transaction.isMalicious {
            showBadReputationIcon()
        } else {
            hideBadReputationIcon()
        }
        setTitle(transaction.compactHash)
        
        let sendAmountColor: UIColor
        let receiveAmountColor: UIColor
        switch transaction.status {
        case .pending, .failed, .notFound:
            sendAmountColor = R.color.text_secondary()!
            receiveAmountColor = R.color.text_secondary()!
        case .success:
            sendAmountColor = R.color.market_red()!
            receiveAmountColor = R.color.market_green()!
        }
        
        if let transfer = transaction.simpleTransfer {
            loadRowViews(count: 1)
            let row = rowViews[0]
            row.style = .singleTransfer
            row.amountLabel.text = transfer.localizedAmountString
            row.amountLabel.textColor = if transfer.directionalAmount.isZero {
                R.color.text_secondary()
            } else if transfer.directionalAmount > 0 {
                receiveAmountColor
            } else {
                sendAmountColor
            }
            if let assetID = transaction.transferAssetID {
                row.symbolLabel.text = symbols[assetID]
            } else {
                row.symbolLabel.text = nil
            }
        } else {
            switch transaction.transactionType.knownCase {
            case .transferIn, .transferOut, .swap, .unknown, .none:
                let count = min(3, transaction.assetChanges.count)
                let rowStyle: RowStackView.Style = count == 1 ? .singleTransfer : .multipleTransfer
                loadRowViews(count: count)
                for i in 0..<count {
                    let row = rowViews[i]
                    row.style = rowStyle
                    let change = transaction.assetChanges[i]
                    row.amountLabel.text = change.amount.formatted(
                        Decimal.FormatStyle.number
                            .locale(.current)
                            .grouping(.never)
                            .sign(strategy: .always())
                            .precision(.fractionLength(0...8))
                            .rounded(rule: .towardZero)
                    )
                    row.amountLabel.textColor = if change.amount >= 0 {
                        receiveAmountColor
                    } else {
                        sendAmountColor
                    }
                    row.symbolLabel.text = symbols[change.assetID]
                }
            case .approval:
                loadRowViews(count: 1)
                let row = rowViews[0]
                row.style = .contract
                if let approval = transaction.approvals?.first {
                    row.amountLabel.text = switch approval.approvalType {
                    case .known(.unlimited):
                        R.string.localizable.approval_unlimited()
                    case .known(.other):
                        R.string.localizable.approval_count(approval.localizedAmount)
                    case .unknown(let value):
                        value
                    }
                } else {
                    row.amountLabel.text = nil
                }
                row.amountLabel.textColor = switch transaction.status {
                case .success:
                    R.color.market_red()!
                default:
                    R.color.text()!
                }
                if let id = transaction.sendAssetID {
                    row.symbolLabel.text = symbols[id]
                } else {
                    row.symbolLabel.text = nil
                }
            }
        }
    }
    
    func load(snapshot: SafeSnapshotItem) {
        // Disable alpha animation for `progressLayer`
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer {
            CATransaction.commit()
        }
        
        statusWrapperView.isHidden = true
        loadRowViews(count: 1)
        let row = rowViews[0]
        row.style = .singleTransfer
        switch SafeSnapshot.SnapshotType(rawValue: snapshot.type) {
        case .pending:
            iconView.imageView.contentMode = .center
            iconView.image = R.image.wallet.snapshot_deposit()
            iconButton.isUserInteractionEnabled = false
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
            row.amountLabel.textColor = R.color.text_tertiary()!
        default:
            progressLayer?.isHidden = true
            if let deposit = snapshot.deposit {
                iconView.imageView.contentMode = .center
                iconView.image = R.image.wallet.snapshot_deposit()
                iconButton.isUserInteractionEnabled = false
                setTitle(deposit.compactSender)
            } else if let withdrawal = snapshot.withdrawal {
                iconView.imageView.contentMode = .center
                iconView.image = R.image.wallet.snapshot_withdrawal()
                iconButton.isUserInteractionEnabled = false
                setTitle(withdrawal.compactReceiver)
            } else if let userID = snapshot.opponentUserID, let name = snapshot.opponentFullname, let url = snapshot.opponentAvatarURL {
                iconView.imageView.contentMode = .scaleAspectFill
                iconView.setImage(with: url, userId: userID, name: name)
                iconButton.isUserInteractionEnabled = true
                setTitle(snapshot.opponentFullname)
            } else {
                iconView.imageView.contentMode = .center
                iconView.image = R.image.wallet.snapshot_anonymous()
                iconButton.isUserInteractionEnabled = false
                setTitle(nil)
            }
            if let withdrawal = snapshot.withdrawal, withdrawal.hash.isEmpty {
                row.amountLabel.textColor = R.color.text_tertiary()!
            } else {
                row.amountLabel.textColor = if snapshot.decimalAmount < 0 {
                    R.color.market_red()
                } else {
                    R.color.market_green()
                }
            }
        }
        if snapshot.isInscription {
            let amount: Decimal = snapshot.decimalAmount > 0 ? 1 : -1
            row.amountLabel.text = CurrencyFormatter.localizedString(
                from: amount,
                format: .precision,
                sign: .always
            )
            row.symbolLabel.isHidden = true
            let inscriptionIconView: InscriptionIconView
            if let view = self.inscriptionIconView {
                view.isHidden = false
                inscriptionIconView = view
            } else {
                inscriptionIconView = InscriptionIconView()
                row.addArrangedSubview(inscriptionIconView)
                inscriptionIconView.snp.makeConstraints { make in
                    make.width.height.equalTo(40).priority(.almostRequired)
                }
                self.inscriptionIconView = inscriptionIconView
            }
            inscriptionIconView.content = snapshot.inscriptionContent
        } else {
            row.amountLabel.text = CurrencyFormatter.localizedString(
                from: snapshot.decimalAmount,
                format: .precision,
                sign: .always
            )
            row.symbolLabel.isHidden = false
            row.symbolLabel.text = snapshot.tokenSymbol
            inscriptionIconView?.isHidden = true
        }
    }
    
}

extension TransactionCell {
    
    private func setTitle(_ title: String?) {
        if let title, !title.isEmpty {
            titleLabel.text = title
            titleLabel.textColor = R.color.text()
        } else {
            titleLabel.text = .notApplicable
            titleLabel.textColor = R.color.text_tertiary()!
        }
    }
    
    private func loadRowViews(count: Int) {
        let diff = rowViews.count - count
        if diff > 0 {
            for view in rowViews.suffix(diff) {
                view.removeFromSuperview()
            }
            rowViews.removeLast(diff)
        } else if diff < 0 {
            for _ in (0 ..< -diff) {
                let view = RowStackView()
                rowViews.append(view)
                assetChangeStackView.addArrangedSubview(view)
            }
        }
    }
    
    private func showBadReputationIcon() {
        if let imageView = badReputationImageView {
            imageView.isHidden = false
        } else {
            let imageView = UIImageView(image: R.image.web3_reputation_bad())
            imageView.setContentHuggingPriority(.required, for: .horizontal)
            imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
            titleStackView.insertArrangedSubview(imageView, at: 0)
            titleStackView.setCustomSpacing(4, after: imageView)
            badReputationImageView = imageView
        }
    }
    
    private func hideBadReputationIcon() {
        badReputationImageView?.isHidden = true
    }
    
    private func layoutProgressLayer() {
        guard let progressLayer else {
            return
        }
        let iconTopLeft: CGPoint = iconView.convert(.zero, to: contentView)
        let progressLeft = iconTopLeft.x + iconView.frame.width / 2
        let fullWidth = contentView.bounds.width - progressLeft
        CATransaction.performWithoutAnimation {
            progressLayer.frame = CGRect(
                x: progressLeft + fullWidth * (1 - progress),
                y: iconTopLeft.y,
                width: fullWidth * progress,
                height: iconView.frame.height
            )
        }
    }
    
}

extension TransactionCell {
    
    private class RowStackView: UIStackView {
        
        enum Style {
            case singleTransfer
            case multipleTransfer
            case contract
        }
        
        let amountLabel = UILabel()
        let symbolLabel = UILabel()
        
        var style: Style = .singleTransfer {
            didSet {
                apply(style: style)
            }
        }
        
        init() {
            amountLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            amountLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            amountLabel.adjustsFontSizeToFitWidth = true
            amountLabel.minimumScaleFactor = 0.1
            amountLabel.textAlignment = .right
            
            symbolLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            symbolLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            symbolLabel.textColor = R.color.text_secondary()
            symbolLabel.setFont(
                scaledFor: .systemFont(ofSize: 12, weight: .medium),
                adjustForContentSize: true
            )
            
            super.init(frame: .zero)
            
            axis = .horizontal
            distribution = .fill
            alignment = .center
            
            addArrangedSubview(amountLabel)
            addArrangedSubview(symbolLabel)
        }
        
        required init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func apply(style: Style) {
            switch style {
            case .singleTransfer:
                amountLabel.setFont(
                    scaledFor: .condensed(size: 19),
                    adjustForContentSize: true
                )
                spacing = 6
            case .multipleTransfer:
                amountLabel.setFont(
                    scaledFor: .condensed(size: 16),
                    adjustForContentSize: true
                )
                spacing = 4
            case .contract:
                amountLabel.setFont(
                    scaledFor: .systemFont(ofSize: 14, weight: .medium),
                    adjustForContentSize: true
                )
                spacing = 4
            }
        }
        
    }
    
}
