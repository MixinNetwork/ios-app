import UIKit
import MixinServices

final class Web3TransactionCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var statusWrapperView: UIView!
    @IBOutlet weak var statusImageView: UIImageView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var assetChangeStackView: UIStackView!
    
    private weak var badReputationImageView: UIImageView?
    
    private var rowViews: [RowStackView] = []
    
    override func awakeFromNib() {
        super.awakeFromNib()
        statusWrapperView.layer.cornerRadius = 7
        statusWrapperView.layer.masksToBounds = true
        statusImageView.layer.cornerRadius = 6
        statusImageView.layer.masksToBounds = true
    }
    
    func load(transaction: Web3Transaction, symbols: [String: String]) {
        if transaction.isMalicious {
            showBadReputationIcon()
        } else {
            hideBadReputationIcon()
        }
        titleLabel.text = transaction.compactHash
        
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
                let senders = transaction.filteredSenders
                let receivers = transaction.filteredReceivers
                let count = min(3, senders.count + receivers.count)
                let rowStyle: RowStackView.Style = count == 1 ? .singleTransfer : .multipleTransfer
                loadRowViews(count: count)
                for i in 0..<count {
                    let row = rowViews[i]
                    row.style = rowStyle
                    if i < receivers.count {
                        let receiver = receivers[i]
                        row.amountLabel.text = receiver.localizedAmount
                        row.amountLabel.textColor = receiveAmountColor
                        row.symbolLabel.text = symbols[receiver.assetID]
                    } else {
                        let sender = senders[i - receivers.count]
                        row.amountLabel.text = sender.localizedAmount
                        row.amountLabel.textColor = sendAmountColor
                        row.symbolLabel.text = symbols[sender.assetID]
                    }
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
        switch transaction.status {
        case .pending:
            statusImageView.image = R.image.transaction_badge_pending()
        case .success:
            statusImageView.image = R.image.transaction_badge_success()
        case .failed, .notFound:
            statusImageView.image = R.image.transaction_badge_failed()
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
    
}

extension Web3TransactionCell {
    
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
