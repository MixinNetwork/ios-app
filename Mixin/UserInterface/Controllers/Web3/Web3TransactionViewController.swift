import UIKit
import MixinServices

final class Web3TransactionViewController: TransactionViewController {
    
    private let token: Web3Token
    private let transaction: Web3Transaction
    
    init(token: Web3Token, transaction: Web3Transaction) {
        self.token = token
        self.transaction = transaction
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.transaction()
        iconView.setIcon(web3Token: token)
        switch transaction.status.knownCase {
        case .success:
            switch transaction.transactionType.knownCase {
            case .send:
                amountLabel.textColor = R.color.market_red()
            case .receive:
                amountLabel.textColor = R.color.market_green()
            case .other, .contract, .none:
                amountLabel.textColor = R.color.text_tertiary()!
            }
        case .failed, .none:
            amountLabel.textColor = R.color.text_tertiary()!
        }
        amountLabel.text = CurrencyFormatter.localizedString(
            from: transaction.signedDecimalAmount,
            format: .precision,
            sign: .always
        )
        symbolLabel.text = token.symbol
        let value = fiatMoneyValue(amount: transaction.decimalAmount, usdPrice: token.decimalUSDPrice)
        fiatMoneyValueLabel.text = R.string.localizable.value_now(value) + "\n "
        layoutTableHeaderView()
        reloadData()
    }
    
}

extension Web3TransactionViewController {
    
    enum TransactionKey: RowKey {
        
        case id
        case transactionHash
        case from
        case to
        case date
        case status
        
        var localized: String {
            switch self {
            case .id:
                return R.string.localizable.transaction_id()
            case .transactionHash:
                return R.string.localizable.transaction_hash()
            case .from:
                return R.string.localizable.from()
            case .to:
                return R.string.localizable.to()
            case .date:
                return R.string.localizable.date()
            case .status:
                return R.string.localizable.status()
            }
        }
        
        var allowsCopy: Bool {
            switch self {
            case .id, .transactionHash, .from, .to:
                true
            default:
                false
            }
        }
        
    }
    
    class TransactionRow: Row {
        
        init(key: TransactionKey, value: String, style: Row.Style = []) {
            super.init(key: key, value: value, style: style)
        }
        
    }
    
    private func reloadData() {
        let transactionAt: String
        if let date = ISO8601DateFormatter.default.date(from: transaction.transactionAt) {
            transactionAt = DateFormatter.dateFull.string(from: date)
        } else {
            transactionAt = transaction.transactionAt
        }
        rows = [
            TransactionRow(key: .id, value: transaction.transactionID),
            TransactionRow(key: .transactionHash, value: transaction.transactionHash),
            TransactionRow(key: .from, value: transaction.sender),
            TransactionRow(key: .to, value: transaction.receiver),
            TransactionRow(key: .date, value: transactionAt),
            TransactionRow(key: .status, value: transaction.status.rawValue.capitalized),
        ]
        tableView.reloadData()
    }
    
}
