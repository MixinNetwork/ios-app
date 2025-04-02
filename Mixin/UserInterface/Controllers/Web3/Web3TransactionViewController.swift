import UIKit
import MixinServices

final class Web3TransactionViewController: TransactionViewController {
    
    private let token: Web3Token
    
    private var transaction: Web3Transaction
    private var reloadPendingTransactionTask: Task<Void, Error>?
    
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
    
    deinit {
        reloadPendingTransactionTask?.cancel()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.transaction()
        iconView.setIcon(web3Token: token)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadDataIfContains(_:)),
            name: Web3TransactionDAO.transactionDidSaveNotification,
            object: nil
        )
        reloadData()
        if transaction.status.knownCase == .pending {
            let walletID = token.walletID
            reloadPendingTransactionTask = Task.detached { [transaction] in
                repeat {
                    do {
                        let transaction = try await RouteAPI.transaction(
                            chainID: transaction.chainID,
                            hash: transaction.transactionHash
                        )
                        if transaction.state.knownCase != .pending {
                            Web3RawTransactionDAO.shared.deleteTransaction(hash: transaction.hash, state: transaction.state)
                            
                            let syncTokens = RefreshWeb3TokenJob(walletID: walletID)
                            ConcurrentJobQueue.shared.addJob(job: syncTokens)
                            let syncTransactions = SyncWeb3TransactionJob(walletID: walletID)
                            ConcurrentJobQueue.shared.addJob(job: syncTransactions)
                            return
                        }
                    } catch {
                        Logger.general.debug(category: "Web3TxnView", message: "\(error)")
                    }
                    try await Task.sleep(nanoseconds: 10 * NSEC_PER_SEC)
                } while !Task.isCancelled
            }
        }
    }
    
    @objc private func reloadDataIfContains(_ notification: Notification) {
        let hash = self.transaction.transactionHash
        guard
            let userInfo = notification.userInfo,
            let transactions = userInfo[Web3TransactionDAO.transactionsUserInfoKey] as? [Web3Transaction],
            let transaction = transactions.first(where: { $0.transactionHash == hash })
        else {
            return
        }
        self.transaction = transaction
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
        case .pending, .failed, .none:
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
        
        let transactionAt: String
        if let date = ISO8601DateFormatter.default.date(from: transaction.transactionAt) {
            transactionAt = DateFormatter.dateFull.string(from: date)
        } else {
            transactionAt = transaction.transactionAt
        }
        rows = [
            TransactionRow(key: .transactionHash, value: transaction.transactionHash),
            TransactionRow(key: .from, value: transaction.sender),
            TransactionRow(key: .to, value: transaction.receiver),
            TransactionRow(key: .date, value: transactionAt),
            TransactionRow(key: .status, value: transaction.status.rawValue.capitalized),
        ]
        if !transaction.transactionID.isEmpty {
            let id = TransactionRow(key: .id, value: transaction.transactionID)
            rows.insert(id, at: 0)
        }
        tableView.reloadData()
    }
    
}
