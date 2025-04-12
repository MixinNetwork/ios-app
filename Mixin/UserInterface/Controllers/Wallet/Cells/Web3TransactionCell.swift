import UIKit
import MixinServices

final class Web3TransactionCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var statusWrapperView: UIView!
    @IBOutlet weak var statusImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var assetChangeStackView: UIStackView!
    
    private var rowViews: [RowStackView] = []
    
    override func awakeFromNib() {
        super.awakeFromNib()
        statusWrapperView.layer.cornerRadius = 7
        statusWrapperView.layer.masksToBounds = true
        statusImageView.layer.cornerRadius = 6
        statusImageView.layer.masksToBounds = true
    }
    
    func load(transaction: Web3Transaction, symbols: [String: String]) {
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
        
        switch transaction.transactionType.knownCase {
        case .transferIn, .transferOut:
            loadRowViews(count: 1)
            let row = rowViews[0]
            row.style = .singleTransfer
            row.amountLabel.text = transaction.localizedTransferAmount
            if let assetID = transaction.transferAssetID {
                row.symbolLabel.text = symbols[assetID]
            } else {
                row.symbolLabel.text = nil
            }
        case .swap, .unknown, .none:
            let senders = transaction.senders ?? []
            let receivers = transaction.receivers ?? []
            let count = min(3, senders.count + receivers.count)
            loadRowViews(count: count)
            for i in 0..<count {
                let row = rowViews[i]
                row.style = .multipleTransfer
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
                case .known(.limited):
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
        
        switch transaction.transactionType.knownCase {
        case .transferIn:
            iconView.image = R.image.wallet.snapshot_deposit()
            rowViews[0].amountLabel.textColor = receiveAmountColor
        case .transferOut:
            iconView.image = R.image.wallet.snapshot_withdrawal()
            rowViews[0].amountLabel.textColor = sendAmountColor
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
