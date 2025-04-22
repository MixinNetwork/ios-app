import UIKit
import MixinServices

final class Web3TransactionViewController: TransactionViewController {
    
    override var viewOnExplorerURL: URL? {
        URL(string: "https://api.mixin.one/external/explore/\(transaction.chainID)/transactions/\(transaction.transactionHash)")
    }
    
    private let walletID: String
    
    private var transaction: Web3Transaction
    private var reloadPendingTransactionTask: Task<Void, Error>?
    private var rows: [Row] = []
    
    private var speedUpOperation: Web3TransferOperation?
    private var cancelOperation: Web3TransferOperation?
    
    init(walletID: String, transaction: Web3Transaction) {
        self.walletID = walletID
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
        tableView.register(R.nib.multipleAssetChangeCell)
        tableView.register(R.nib.authenticationPreviewInfoCell)
        tableView.dataSource = self
        tableView.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadDataIfContains(_:)),
            name: Web3TransactionDAO.transactionDidSaveNotification,
            object: nil
        )
        reloadData()
        if transaction.status == .pending {
            reloadPendingTransactionTask = Task { [walletID, transaction, weak self] in
                repeat {
                    do {
                        let localTransaction = Web3TransactionDAO.shared.transaction(
                            hash: transaction.transactionHash,
                            chainID: transaction.chainID,
                            address: transaction.address
                        )
                        guard let localTransaction else {
                            return
                        }
                        
                        if localTransaction.status != .pending {
                            await MainActor.run {
                                guard let self else {
                                    return
                                }
                                self.transaction = localTransaction
                                self.reloadData()
                            }
                            return
                        }
                        
                        if Web3RawTransactionDAO.shared.rawTransactionExists(hash: transaction.transactionHash) {
                            let transaction = try await RouteAPI.transaction(
                                chainID: transaction.chainID,
                                hash: transaction.transactionHash
                            )
                            if transaction.state.knownCase != .pending {
                                try Web3RawTransactionDAO.shared.deleteRawTransaction(hash: transaction.hash) { db in
                                    if transaction.state.knownCase == .notFound {
                                        try Web3TransactionDAO.shared.setTransactionStatusNotFound(
                                            hash: transaction.hash,
                                            chainID: transaction.chainID,
                                            address: transaction.account,
                                            db: db
                                        )
                                    }
                                }
                            }
                        }
                        
                        // TODO: Is it really necessary to refresh the balance and transaction history here? Wouldn’t it be sufficient to refresh only when state changes?
                        let syncTokens = RefreshWeb3TokenJob(walletID: walletID)
                        ConcurrentJobQueue.shared.addJob(job: syncTokens)
                        let syncTransactions = SyncWeb3TransactionJob(walletID: walletID)
                        ConcurrentJobQueue.shared.addJob(job: syncTransactions)
                    } catch {
                        Logger.general.debug(category: "Web3TxnView", message: "\(error)")
                    }
                    try await Task.sleep(nanoseconds: 10 * NSEC_PER_SEC)
                } while !Task.isCancelled
            }
        }
    }
    
    @objc private func reloadDataIfContains(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let transactions = userInfo[Web3TransactionDAO.transactionsUserInfoKey] as? [Web3Transaction],
            let transaction = transactions.first(where: { $0.matches(with: transaction) })
        else {
            return
        }
        self.transaction = transaction
        reloadData()
    }
    
}

extension Web3TransactionViewController: PillActionView.Delegate {
    
    func pillActionView(_ view: PillActionView, didSelectActionAtIndex index: Int) {
        guard let action = Web3TransactionTableHeaderViewAction(rawValue: index) else {
            return
        }
        switch action {
        case .speedUp:
            guard let operation = speedUpOperation else {
                return
            }
            let preview = Web3TransferPreviewViewController(operation: operation, proposer: .speedUp)
            present(preview, animated: true)
        case .cancel:
            guard let operation = cancelOperation else {
                return
            }
            let preview = Web3TransferPreviewViewController(operation: operation, proposer: .cancel)
            present(preview, animated: true)
        }
    }
    
}

extension Web3TransactionViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch rows[indexPath.row] {
        case let .plain(key, value):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.snapshot_column, for: indexPath)!
            cell.titleLabel.text = key.localized.uppercased()
            cell.subtitleLabel.text = value
            cell.subtitleLabel.textColor = R.color.text()
            cell.disclosureIndicatorImageView.isHidden = true
            return cell
        case let .assetChanges(changes):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.multiple_asset_change, for: indexPath)!
            cell.contentLeadingConstraint.constant = 20
            cell.contentTrailingConstraint.constant = 20
            cell.titleLabel.text = R.string.localizable.asset_changes().uppercased()
            cell.reloadData(numberOfAssetChanges: changes.count) { index, row in
                let change = changes[index]
                if let token = change.token {
                    row.iconView.setIcon(token: token)
                }
                let amountColor = switch change.style {
                case .send:
                    R.color.error_red()!
                case .receive:
                    R.color.market_green()!
                case .pending:
                    R.color.text()!
                }
                let amount = NSMutableAttributedString(
                    string: change.amount,
                    attributes: [
                        .font: UIFont.preferredFont(forTextStyle: .callout),
                        .foregroundColor: amountColor,
                    ]
                )
                if let symbol = change.token?.symbol {
                    let attributedSymbol = NSAttributedString(
                        string: " " + symbol,
                        attributes: [
                            .font: UIFont.preferredFont(forTextStyle: .callout),
                            .foregroundColor: R.color.text()!,
                        ]
                    )
                    amount.append(attributedSymbol)
                }
                row.amountLabel.attributedText = amount
                row.networkLabel.text = nil
            }
            return cell
        case let .fee(token, fiatMoney):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_info, for: indexPath)!
            cell.contentLeadingConstraint.constant = 20
            cell.contentTrailingConstraint.constant = 20
            cell.captionLabel.text = R.string.localizable.network_fee().uppercased()
            cell.primaryLabel.text = token
            cell.secondaryLabel.text = fiatMoney
            cell.setPrimaryLabel(usesBoldFont: false)
            cell.trailingContent = nil
            return cell
        case let .approval(token, amount):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.multiple_asset_change, for: indexPath)!
            cell.contentLeadingConstraint.constant = 20
            cell.contentTrailingConstraint.constant = 20
            cell.titleLabel.text = R.string.localizable.token_access_approval().uppercased()
            cell.reloadData(numberOfAssetChanges: 1) { index, row in
                row.iconView.setIcon(token: token)
                let amountColor = switch transaction.status {
                case .success:
                    R.color.market_red()!
                default:
                    R.color.text()!
                }
                let amount = NSMutableAttributedString(
                    string: amount,
                    attributes: [
                        .font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 16, weight: .medium)),
                        .foregroundColor: amountColor,
                    ]
                )
                let attributedSymbol = NSAttributedString(
                    string: " " + token.symbol,
                    attributes: [
                        .font: UIFont.preferredFont(forTextStyle: .callout),
                        .foregroundColor: R.color.text_secondary()!,
                    ]
                )
                amount.append(attributedSymbol)
                row.amountLabel.attributedText = amount
                row.networkLabel.text = nil
            }
            return cell
        }
    }
    
}

extension Web3TransactionViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        rows[indexPath.row].allowsCopy
    }
    
    func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        rows[indexPath.row].allowsCopy && action == #selector(copy(_:))
    }
    
    func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        switch rows[indexPath.row] {
        case let .plain(_, value):
            UIPasteboard.general.string = value
            showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
        default:
            break
        }
    }
    
}

extension Web3TransactionViewController {
    
    private struct AssetChange {
        
        enum Style {
            case send
            case receive
            case pending
        }
        
        let token: (any Token)?
        let amount: String
        let style: Style
        
    }
    
    private enum Row {
        
        case plain(key: Key, value: String)
        case assetChanges([AssetChange])
        case fee(token: String, fiatMoney: String)
        case approval(token: any Token, amount: String)
        
        var allowsCopy: Bool {
            switch self {
            case let .plain(key, _):
                key.allowsCopy
            default:
                false
            }
        }
        
    }
    
    private enum Key {
        
        case transactionHash
        case from
        case to
        case fee
        case type
        case network
        case date
        
        var localized: String {
            switch self {
            case .transactionHash:
                R.string.localizable.transaction_hash()
            case .from:
                R.string.localizable.from()
            case .to:
                R.string.localizable.to()
            case .fee:
                R.string.localizable.network_fee()
            case .type:
                R.string.localizable.type()
            case .network:
                R.string.localizable.network()
            case .date:
                R.string.localizable.date()
            }
        }
        
        var allowsCopy: Bool {
            switch self {
            case .transactionHash, .from, .to:
                true
            default:
                false
            }
        }
        
    }
    
    private func reloadData() {
        let simpleHeaderView: SimpleWeb3TransactionTableHeaderView = tableView.tableHeaderView as? SimpleWeb3TransactionTableHeaderView
            ?? R.nib.simpleWeb3TransactionTableHeaderView(withOwner: nil)!
        let complexHeaderView: ComplexWeb3TransactionTableHeaderView = tableView.tableHeaderView as? ComplexWeb3TransactionTableHeaderView
            ?? R.nib.complexWeb3TransactionTableHeaderView(withOwner: nil)!
        
        let feeToken = Web3TokenDAO.shared.token(walletID: walletID, assetID: transaction.chainID)
        let feeRow: Row
        if let feeToken, let amount = Decimal(string: transaction.fee, locale: .enUSPOSIX) {
            feeRow = .fee(
                token: CurrencyFormatter.localizedString(
                    from: amount,
                    format: .precision,
                    sign: .never,
                    symbol: .custom(feeToken.symbol)
                ),
                fiatMoney: CurrencyFormatter.localizedString(
                    from: amount * feeToken.decimalUSDPrice * Currency.current.decimalRate,
                    format: .precision,
                    sign: .never,
                    symbol: .currencySymbol
                )
            )
        } else {
            feeRow = .plain(key: .fee, value: transaction.fee)
        }
        
        switch transaction.transactionType.knownCase {
        case .transferIn, .transferOut:
            if let assetID = transaction.transferAssetID,
               !assetID.isEmpty,
               let token = Web3TokenDAO.shared.token(walletID: walletID, assetID: assetID)
            {
                simpleHeaderView.iconView.setIcon(web3Token: token)
                simpleHeaderView.symbolLabel.text = token.symbol
            } else {
                simpleHeaderView.symbolLabel.text = nil
            }
            switch transaction.status {
            case .success:
                switch transaction.transactionType.knownCase {
                case .transferIn:
                    simpleHeaderView.amountLabel.textColor = R.color.market_green()
                case .transferOut:
                    simpleHeaderView.amountLabel.textColor = R.color.market_red()
                default:
                    break
                }
            case .failed, .pending, .notFound:
                simpleHeaderView.amountLabel.textColor = R.color.text_tertiary()
            }
        case .none, .unknown:
            complexHeaderView.iconView.image = R.image.transaction_type_unknown()
            complexHeaderView.titleLabel.text = transaction.transactionType.localized
        case .swap:
            complexHeaderView.iconView.image = R.image.transaction_type_swap()
            complexHeaderView.titleLabel.text = R.string.localizable.swap()
        case .approval:
            complexHeaderView.iconView.image = R.image.transaction_type_approval()
            complexHeaderView.titleLabel.text = R.string.localizable.approval()
        }
        
        switch transaction.transactionType.knownCase {
        case .transferIn, .transferOut:
            if let amount = transaction.directionalTransferAmount {
                simpleHeaderView.amountLabel.text = CurrencyFormatter.localizedString(
                    from: amount,
                    format: .precision,
                    sign: .always
                )
            } else {
                simpleHeaderView.amountLabel.text = nil
            }
            simpleHeaderView.statusLabel.load(status: transaction.status)
            tableView.tableHeaderView = simpleHeaderView
        case .none, .unknown, .swap, .approval:
            complexHeaderView.statusLabel.load(status: transaction.status)
            tableView.tableHeaderView = complexHeaderView
        }
        
        layoutTableHeaderView()
        
        switch transaction.transactionType.knownCase {
        case .transferIn:
            rows = [
                .plain(key: .transactionHash, value: transaction.transactionHash),
            ]
            if let fromAddress = transaction.senders?.first?.from {
                rows.append(.plain(key: .from, value: fromAddress))
            }
            rows.append(feeRow)
        case .transferOut:
            rows = [
                .plain(key: .transactionHash, value: transaction.transactionHash),
            ]
            if let toAddress = transaction.receivers?.first?.to {
                rows.append(.plain(key: .to, value: toAddress))
            }
            rows.append(feeRow)
        case .swap, .none, .unknown:
            let tokens = Web3TokenDAO.shared.tokens(walletID: walletID, ids: transaction.allAssetIDs)
                .reduce(into: [:]) { result, token in
                    result[token.assetID] = token
                }
            let sendStyle: AssetChange.Style
            let receiveStyle: AssetChange.Style
            switch transaction.status {
            case .success:
                sendStyle = .send
                receiveStyle = .receive
            default:
                sendStyle = .pending
                receiveStyle = .pending
            }
            let receivers = transaction.receivers ?? []
            let senders = transaction.senders ?? []
            let changes = receivers.map { receiver in
                let token = tokens[receiver.assetID]
                let amount = if let amount = Decimal(string: receiver.amount, locale: .enUSPOSIX) {
                    CurrencyFormatter.localizedString(
                        from: amount,
                        format: .precision,
                        sign: .always
                    )
                } else {
                    receiver.amount
                }
                return AssetChange(token: token, amount: amount, style: receiveStyle)
            } + senders.map { sender in
                let token = tokens[sender.assetID]
                let amount = if let amount = Decimal(string: sender.amount, locale: .enUSPOSIX) {
                    CurrencyFormatter.localizedString(
                        from: -amount,
                        format: .precision,
                        sign: .always
                    )
                } else {
                    "-" + sender.amount
                }
                return AssetChange(token: token, amount: amount, style: sendStyle)
            }
            if changes.isEmpty {
                rows = []
            } else {
                rows = [.assetChanges(changes)]
            }
            rows.append(contentsOf: [
                .plain(key: .transactionHash, value: transaction.transactionHash),
                feeRow,
            ])
        case .approval:
            if let approval = transaction.approvals?.first,
               let token = Web3TokenDAO.shared.token(walletID: walletID, assetID: approval.assetID)
            {
                let localizedAmount = switch approval.approvalType {
                case .known(.unlimited):
                    R.string.localizable.approval_unlimited()
                case .known(.other):
                    R.string.localizable.approval_count(approval.localizedAmount)
                case .unknown(let value):
                    value
                }
                rows = [.approval(token: token, amount: localizedAmount)]
            } else {
                rows = []
            }
            rows.append(.plain(key: .transactionHash, value: transaction.transactionHash))
            if let toAddress = transaction.receivers?.first?.to {
                rows.append(.plain(key: .to, value: toAddress))
            }
        }
        
        rows.append(.plain(key: .type, value: transaction.transactionType.localized))
        
        if let network = feeToken?.depositNetworkName {
            rows.append(.plain(key: .network, value: network))
        }
        
        let transactionAt: String
        let date = DateFormatter.iso8601Full.date(from: transaction.transactionAt)
        ?? ISO8601DateFormatter.default.date(from: transaction.transactionAt)
        if let date {
            transactionAt = DateFormatter.dateFull.string(from: date)
        } else {
            transactionAt = transaction.transactionAt
        }
        rows.append(.plain(key: .date, value: transactionAt))
        
        tableView.reloadData()
        
        if transaction.status == .pending {
            let hash = transaction.transactionHash
            DispatchQueue.global().async { [walletID, weak self] in
                let operations: (speedUp: Web3TransferOperation, cancel: Web3TransferOperation)? = {
                    guard
                        let rawTransaction = Web3RawTransactionDAO.shared.pendingRawTransaction(hash: hash),
                        let chain = Web3Chain.chain(chainID: rawTransaction.chainID),
                        chain.kind == .evm,
                        let transaction = EIP1559Transaction(rawTransaction: rawTransaction.raw)
                    else {
                        return nil
                    }
                    do {
                        let speedUp = try EVMSpeedUpOperation(
                            walletID: walletID,
                            fromAddress: rawTransaction.account,
                            transaction: transaction,
                            chain: chain
                        )
                        let cancel = try EVMCancelOperation(
                            walletID: walletID,
                            fromAddress: rawTransaction.account,
                            transaction: transaction,
                            chain: chain
                        )
                        return (speedUp: speedUp, cancel: cancel)
                    } catch {
                        Logger.general.debug(category: "Web3Txn", message: "Create op failed: \(error)")
                        return nil
                    }
                }()
                DispatchQueue.main.async {
                    guard let self, let headerView = self.tableView.tableHeaderView as? Web3TransactionTableHeaderView else {
                        return
                    }
                    if let operations {
                        self.speedUpOperation = operations.speedUp
                        self.cancelOperation = operations.cancel
                        headerView.showActionView()
                        headerView.actionView?.delegate = self
                    } else {
                        self.speedUpOperation = nil
                        self.cancelOperation = nil
                        headerView.hideActionView()
                    }
                    self.layoutTableHeaderView()
                }
            }
        }
    }
    
}
