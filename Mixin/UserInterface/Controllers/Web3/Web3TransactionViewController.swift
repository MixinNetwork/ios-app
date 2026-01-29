import UIKit
import MixinServices

final class Web3TransactionViewController: TransactionViewController {
    
    override var viewOnExplorerURL: URL? {
        URL(string: "https://api.mixin.one/external/explore/\(transaction.chainID)/transactions/\(transaction.transactionHash)")
    }
    
    private let wallet: Web3Wallet
    
    private var transaction: Web3Transaction
    private var rows: [Row] = []
    
    private var speedUpOperation: Web3TransferOperation?
    private var cancelOperation: Web3TransferOperation?
    
    private var reviewPendingTransactionJobID: String?
    
    init(wallet: Web3Wallet, transaction: Web3Transaction) {
        self.wallet = wallet
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
        navigationItem.titleView = NavigationTitleView(
            title: R.string.localizable.transaction(),
            subtitle: wallet.name
        )
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
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if transaction.status == .pending {
            let walletID = wallet.walletID
            let jobs = [
                ReviewPendingWeb3RawTransactionJob(walletID: walletID),
                ReviewPendingWeb3TransactionJob(walletID: walletID),
            ]
            reviewPendingTransactionJobID = jobs[1].getJobId()
            for job in jobs {
                ConcurrentJobQueue.shared.addJob(job: job)
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let id = reviewPendingTransactionJobID {
            ConcurrentJobQueue.shared.cancelJob(jobId: id)
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
            let preview = Web3TransferPreviewViewController(
                operation: operation,
                proposer: .speedUp(sender: self)
            )
            preview.manipulateNavigationStackOnFinished = true
            present(preview, animated: true)
        case .cancel:
            guard let operation = cancelOperation else {
                return
            }
            let preview = Web3TransferPreviewViewController(
                operation: operation,
                proposer: .cancel(sender: self)
            )
            preview.manipulateNavigationStackOnFinished = true
            present(preview, animated: true)
        }
        // Once operation is previewed, the fee will be loaded and never update again
        // Make new operations to keep the fee untouched
        reloadOverridingOperations()
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
            cell.titleLabel.text = R.string.localizable.balance_changes().uppercased()
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
            cell.titleLabel.text = R.string.localizable.preauthorize_amount().uppercased()
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
        if let transfer = transaction.simpleTransfer {
            let simpleHeaderView = tableView.tableHeaderView as? SimpleWeb3TransactionTableHeaderView
            ?? R.nib.simpleWeb3TransactionTableHeaderView(withOwner: nil)!
            if let token = Web3TokenDAO.shared.token(walletID: wallet.walletID, assetID: transfer.assetID) {
                simpleHeaderView.iconView.setIcon(web3Token: token)
                simpleHeaderView.symbolLabel.text = token.symbol
            } else {
                simpleHeaderView.symbolLabel.text = nil
            }
            simpleHeaderView.amountLabel.textColor = switch transaction.status {
            case .success where !transfer.directionalAmount.isZero:
                switch transaction.transactionType.knownCase {
                case .transferIn:
                    R.color.market_green()
                case .transferOut:
                    R.color.market_red()
                default:
                    R.color.text_tertiary()
                }
            default:
                R.color.text_tertiary()
            }
            simpleHeaderView.amountLabel.text = transfer.localizedAmountString
            simpleHeaderView.statusLabel.load(status: transaction.status)
            tableView.tableHeaderView = simpleHeaderView
        } else {
            let complexHeaderView = tableView.tableHeaderView as? ComplexWeb3TransactionTableHeaderView
            ?? R.nib.complexWeb3TransactionTableHeaderView(withOwner: nil)!
            switch transaction.transactionType.knownCase {
            case .transferIn:
                complexHeaderView.iconView.image = R.image.transaction_type_transfer_in()
            case .transferOut:
                complexHeaderView.iconView.image = R.image.transaction_type_transfer_out()
            case .none, .unknown:
                complexHeaderView.iconView.image = R.image.transaction_type_unknown()
            case .swap:
                complexHeaderView.iconView.image = R.image.transaction_type_swap()
            case .approval:
                complexHeaderView.iconView.image = R.image.transaction_type_approval()
            }
            complexHeaderView.titleLabel.text = transaction.transactionType.localized
            complexHeaderView.statusLabel.load(status: transaction.status)
            tableView.tableHeaderView = complexHeaderView
        }
        if let headerView = tableView.tableHeaderView as? Web3TransactionTableHeaderView {
            if transaction.isMalicious {
                headerView.showMaliciousWarningView()
            } else {
                headerView.hideMaliciousWarningView()
            }
        }
        layoutTableHeaderView()
        
        let feeToken = Web3TokenDAO.shared.token(walletID: wallet.walletID, assetID: transaction.chainID)
        let feeRow: Row? = switch transaction.transactionType.knownCase {
        case .transferIn:
            nil
        default:
            if let feeToken, let amount = Decimal(string: transaction.fee, locale: .enUSPOSIX) {
                .fee(
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
                .plain(key: .fee, value: transaction.fee)
            }
        }
        
        if let transfer = transaction.simpleTransfer {
            rows = [
                .plain(key: .transactionHash, value: transaction.transactionHash),
            ]
            if let fromAddress = transfer.fromAddress {
                rows.append(.plain(key: .from, value: fromAddress))
            } else if let toAddress = transfer.toAddress {
                rows.append(.plain(key: .to, value: toAddress))
            }
            if let feeRow {
                rows.append(feeRow)
            }
        } else {
            switch transaction.transactionType.knownCase {
            case .transferIn, .transferOut, .swap, .none, .unknown:
                let tokens = Web3TokenDAO.shared.tokens(walletID: wallet.walletID, ids: transaction.allAssetIDs)
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
                
                let changes = transaction.filteredReceivers.map { receiver in
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
                } + transaction.filteredSenders.map { sender in
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
                rows.append(.plain(key: .transactionHash, value: transaction.transactionHash))
                if let feeRow {
                    rows.append(feeRow)
                }
            case .approval:
                if let approval = transaction.approvals?.first,
                   let token = Web3TokenDAO.shared.token(walletID: wallet.walletID, assetID: approval.assetID)
                {
                    let localizedAmount = switch approval.approvalType {
                    case .known(.unlimited):
                        R.string.localizable.approval_unlimited()
                    case .known(.other):
                        approval.localizedAmount
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
        }
        
        rows.append(.plain(key: .type, value: transaction.transactionType.localized))
        
        if let network = feeToken?.depositNetworkName {
            rows.append(.plain(key: .network, value: network))
        }
        
        let transactionAt: String = if let date = transaction.transactionAtDate {
            DateFormatter.dateFull.string(from: date)
        } else {
            transaction.transactionAt
        }
        rows.append(.plain(key: .date, value: transactionAt))
        
        tableView.reloadData()
        reloadOverridingOperations()
    }
    
    private func reloadOverridingOperations() {
        guard
            transaction.status == .pending,
            let chain = Web3Chain.chain(chainID: transaction.chainID)
        else {
            reloadHeaderView(speedUpOperation: nil, cancelOperation: nil)
            return
        }
        let hash = transaction.transactionHash
        switch chain.kind {
        case .solana:
            break
        case .bitcoin:
            DispatchQueue.global().async { [wallet, weak self] in
                let speedUpOperation: Web3TransferOperation?
                let cancelOperation: Web3TransferOperation?
                if let fromAddress = Web3AddressDAO.shared.address(walletID: wallet.walletID, chainID: chain.chainID),
                   let rawTransaction = Web3RawTransactionDAO.shared.pendingRawTransaction(hash: hash)
                {
                    do {
                        speedUpOperation = try BitcoinSpeedUpOperation(
                            wallet: wallet,
                            fromAddress: fromAddress,
                            transaction: rawTransaction,
                        )
                    } catch {
                        Logger.general.debug(category: "Web3Txn", message: "Speed up failed: \(error)")
                        speedUpOperation = nil
                    }
                    do {
                        cancelOperation = try BitcoinCancelOperation(
                            wallet: wallet,
                            fromAddress: fromAddress,
                            transaction: rawTransaction,
                        )
                    } catch {
                        Logger.general.debug(category: "Web3Txn", message: "Cancel failed: \(error)")
                        cancelOperation = nil
                    }
                } else {
                    speedUpOperation = nil
                    cancelOperation = nil
                }
                DispatchQueue.main.async {
                    self?.reloadHeaderView(
                        speedUpOperation: speedUpOperation,
                        cancelOperation: cancelOperation
                    )
                }
            }
        case .evm:
            DispatchQueue.global().async { [wallet, weak self] in
                let speedUpOperation: Web3TransferOperation?
                let cancelOperation: Web3TransferOperation?
                if let fromAddress = Web3AddressDAO.shared.address(walletID: wallet.walletID, chainID: chain.chainID),
                   let rawTransaction = Web3RawTransactionDAO.shared.pendingRawTransaction(hash: hash),
                   let transaction = EIP1559Transaction(rawTransaction: rawTransaction.raw)
                {
                    do {
                        speedUpOperation = try EVMSpeedUpOperation(
                            wallet: wallet,
                            fromAddress: fromAddress,
                            transaction: transaction,
                            chain: chain
                        )
                    } catch {
                        Logger.general.debug(category: "Web3Txn", message: "Speed up failed: \(error)")
                        speedUpOperation = nil
                    }
                    do {
                        cancelOperation = try EVMCancelOperation(
                            wallet: wallet,
                            fromAddress: fromAddress,
                            transaction: transaction,
                            chain: chain
                        )
                    } catch {
                        Logger.general.debug(category: "Web3Txn", message: "Cancel failed: \(error)")
                        cancelOperation = nil
                    }
                } else {
                    speedUpOperation = nil
                    cancelOperation = nil
                }
                DispatchQueue.main.async {
                    self?.reloadHeaderView(
                        speedUpOperation: speedUpOperation,
                        cancelOperation: cancelOperation
                    )
                }
            }
        }
    }
    
    private func reloadHeaderView(
        speedUpOperation: Web3TransferOperation?,
        cancelOperation: Web3TransferOperation?
    ) {
        self.speedUpOperation = speedUpOperation
        self.cancelOperation = cancelOperation
        guard let headerView = self.tableView.tableHeaderView as? Web3TransactionTableHeaderView else {
            return
        }
        var actions: [Web3TransactionTableHeaderViewAction] = []
        if speedUpOperation != nil {
            actions.append(.speedUp)
        }
        if cancelOperation != nil {
            actions.append(.cancel)
        }
        if actions.isEmpty {
            headerView.hideActionView()
        } else {
            headerView.showActionView(actions: actions)
            headerView.actionView?.delegate = self
        }
        self.layoutTableHeaderView()
        self.tableView.tableHeaderView = headerView
    }
    
}
