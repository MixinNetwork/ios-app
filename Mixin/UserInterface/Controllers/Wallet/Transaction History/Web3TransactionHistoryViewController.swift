import UIKit
import MixinServices

final class Web3TransactionHistoryViewController: TransactionHistoryViewController {
    
    private typealias DateRepresentation = String
    private typealias DiffableDataSource = UITableViewDiffableDataSource<DateRepresentation, Web3Transaction.ID>
    private typealias DataSourceSnapshot = NSDiffableDataSourceSnapshot<DateRepresentation, Web3Transaction.ID>
    
    let wallet: Web3Wallet
    
    private var reputationFilterView = TransactionHistoryReputationFilterView()
    
    private var filter: Web3Transaction.Filter
    private var order: Web3Transaction.Order = .newest
    private var dataSource: DiffableDataSource!
    private var items: [Web3Transaction.ID: Web3Transaction] = [:]
    private var tokenSymbols: [String: String] = [:]
    
    private var loadPreviousPageIndexPath: IndexPath?
    private var firstItem: Web3Transaction?
    
    private var loadNextPageIndexPath: IndexPath?
    private var lastItem: Web3Transaction?
    
    private var reviewPendingTransactionJobID: String?
    
    init(wallet: Web3Wallet, token: Web3TokenItem) {
        let reputationOptions = Web3Reputation.FilterOption.options(token: token)
        self.wallet = wallet
        self.filter = .init(tokens: [token], reputationOptions: reputationOptions)
        super.init()
    }
    
    init(wallet: Web3Wallet, type: Web3Transaction.DisplayType?) {
        self.wallet = wallet
        self.filter = .init(type: type)
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateNavigationSubtitle(order: order)
        reloadRightBarButtonItem(order: order)
        
        let typeFilterActions = typeFilterActions(selectedType: filter.type)
        typeFilterView.reloadData(type: filter.type)
        typeFilterView.button.menu = UIMenu(children: typeFilterActions)
        assetFilterView.reloadData(tokens: filter.tokens)
        assetFilterView.button.addTarget(self, action: #selector(pickTokens(_:)), for: .touchUpInside)
        recipientFilterView.reloadData(users: [], addresses: filter.addresses)
        recipientFilterView.button.addTarget(self, action: #selector(pickRecipients(_:)), for: .touchUpInside)
        dateFilterView.reloadData(startDate: filter.startDate, endDate: filter.endDate)
        dateFilterView.button.addTarget(self, action: #selector(pickDates(_:)), for: .touchUpInside)
        reputationFilterView.reloadData(options: filter.reputationOptions)
        reputationFilterView.button.addTarget(self, action: #selector(pickReputation(_:)), for: .touchUpInside)
        filtersStackView.addArrangedSubview(reputationFilterView)
        
        tableView.register(R.nib.web3TransactionCell)
        tableView.register(AssetHeaderView.self, forHeaderFooterViewReuseIdentifier: headerReuseIdentifier)
        tableView.delegate = self
        dataSource = DiffableDataSource(tableView: tableView) { [weak self] (tableView, indexPath, transactionID) in
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.web3_transaction, for: indexPath)!
            if let self {
                let transaction = self.items[transactionID]!
                cell.load(transaction: transaction, symbols: self.tokenSymbols)
            }
            return cell
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadData),
            name: Web3TransactionDAO.transactionDidSaveNotification,
            object: nil
        )
        reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let walletID = wallet.walletID
        let jobs = [
            SyncWeb3TransactionJob(walletID: walletID),
            ReviewPendingWeb3RawTransactionJob(walletID: walletID),
            ReviewPendingWeb3TransactionJob(walletID: walletID),
        ]
        reviewPendingTransactionJobID = jobs[2].getJobId()
        for job in jobs {
            ConcurrentJobQueue.shared.addJob(job: job)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let id = reviewPendingTransactionJobID {
            ConcurrentJobQueue.shared.cancelJob(jobId: id)
        }
    }
    
    @objc private func pickTokens(_ sender: Any) {
        let picker = Web3TransactionHistoryTokenFilterPickerViewController(selectedTokens: filter.tokens)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc private func pickReputation(_ sender: Any) {
        let picker = Web3ReputationPickerViewController(options: filter.reputationOptions)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc private func pickRecipients(_ sender: Any) {
        let picker = TransactionHistoryRecipientFilterPickerViewController(
            segments: [.address],
            users: [],
            addresses: filter.addresses
        )
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc private func pickDates(_ sender: Any) {
        let picker = TransactionHistoryDatePickerViewController(startDate: filter.startDate, endDate: filter.endDate)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc private func reloadData() {
        queue.cancelAllOperations()
        loadPreviousPageIndexPath = nil
        loadNextPageIndexPath = nil
        let operation = LoadLocalDataOperation(
            viewController: self,
            behavior: .reload,
            filter: filter,
            order: order
        )
        queue.addOperation(operation)
    }
    
}

extension Web3TransactionHistoryViewController {
    
    private func updateNavigationSubtitle(order: Web3Transaction.Order) {
        guard let titleView = navigationItem.titleView as? NavigationTitleView else {
            return
        }
        titleView.subtitle = switch order {
        case .newest:
            R.string.localizable.sort_by_recent()
        case .oldest:
            R.string.localizable.sort_by_oldest()
        }
    }
    
    private func typeFilterActions(selectedType type: Web3Transaction.DisplayType?) -> [UIAction] {
        let actions = [
            UIAction(
                title: R.string.localizable.all(),
                state: .off,
                handler: { [weak self] _ in self?.reloadDataWithFilterType(nil) }
            ),
            UIAction(
                title: R.string.localizable.receive(),
                image: R.image.filter_deposit(),
                state: .off,
                handler: { [weak self] _ in self?.reloadDataWithFilterType(.receive) }
            ),
            UIAction(
                title: R.string.localizable.send(),
                image: R.image.filter_withdrawal(),
                state: .off,
                handler: { [weak self] _ in self?.reloadDataWithFilterType(.send) }
            ),
            UIAction(
                title: R.string.localizable.trade(),
                image: R.image.filter_swap(),
                state: .off,
                handler: { [weak self] _ in self?.reloadDataWithFilterType(.swap) }
            ),
            UIAction(
                title: R.string.localizable.approval(),
                image: R.image.filter_approval(),
                state: .off,
                handler: { [weak self] _ in self?.reloadDataWithFilterType(.approval) }
            ),
            UIAction(
                title: R.string.localizable.pending(),
                image: R.image.filter_pending(),
                state: .off,
                handler: { [weak self] _ in self?.reloadDataWithFilterType(.pending) }
            ),
        ]
        switch type {
        case .none:
            actions[0].state = .on
        case .receive:
            actions[1].state = .on
        case .send:
            actions[2].state = .on
        case .swap:
            actions[3].state = .on
        case .approval:
            actions[4].state = .on
        case .pending:
            actions[5].state = .on
        }
        return actions
    }
    
    private func reloadRightBarButtonItem(order: Web3Transaction.Order) {
        let rightBarButtonItem: UIBarButtonItem
        if let item = navigationItem.rightBarButtonItem {
            rightBarButtonItem = item
        } else {
            rightBarButtonItem = .tintedIcon(image: R.image.navigation_filter(), target: nil, action: nil)
            navigationItem.rightBarButtonItem = rightBarButtonItem
        }
        let actions = [
            UIAction(
                title: R.string.localizable.recent(),
                image: R.image.order_newest(),
                state: .off,
                handler: { [weak self] _ in self?.reloadDataWithOrder(.newest) }
            ),
            UIAction(
                title: R.string.localizable.oldest(),
                image: R.image.order_oldest(),
                state: .off,
                handler: { [weak self] _ in self?.reloadDataWithOrder(.oldest) }
            ),
        ]
        switch order {
        case .newest:
            actions[0].state = .on
        case .oldest:
            actions[1].state = .on
        }
        rightBarButtonItem.menu = UIMenu(children: actions)
    }
    
    private func reloadDataWithFilterType(_ type: Web3Transaction.DisplayType?) {
        filter.type = type
        let actions = typeFilterActions(selectedType: filter.type)
        typeFilterView.button.menu = UIMenu(children: actions)
        typeFilterView.reloadData(type: type)
        reloadData()
    }
    
    private func reloadDataWithOrder(_ order: Web3Transaction.Order) {
        self.order = order
        updateNavigationSubtitle(order: order)
        reloadRightBarButtonItem(order: order)
        reloadData()
    }
    
}

extension Web3TransactionHistoryViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseIdentifier) as! AssetHeaderView
        view.label.text = dataSource.sectionIdentifier(for: section)
        return view
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        44
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        switch indexPath {
        case loadPreviousPageIndexPath:
            Logger.general.debug(category: "TxnHistory", message: "Previous canary consumed")
            loadPreviousPageIndexPath = nil
            loadPreviousPage()
        case loadNextPageIndexPath:
            Logger.general.debug(category: "TxnHistory", message: "Next canary consumed")
            loadNextPageIndexPath = nil
            loadNextPage()
        default:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let id = dataSource.itemIdentifier(for: indexPath), let item = items[id] else {
            return
        }
        let viewController = Web3TransactionViewController(wallet: wallet, transaction: item)
        navigationController?.pushViewController(viewController, animated: true)
    }
    
}

extension Web3TransactionHistoryViewController: Web3TransactionHistoryTokenFilterPickerViewControllerDelegate {
    
    func web3TransactionHistoryTokenFilterPickerViewController(
        _ controller: Web3TransactionHistoryTokenFilterPickerViewController,
        didPickTokens tokens: [Web3TokenItem]
    ) {
        filter.tokens = tokens
        assetFilterView.reloadData(tokens: tokens)
        reloadData()
    }
    
}

extension Web3TransactionHistoryViewController: TransactionHistoryRecipientFilterPickerViewControllerDelegate {
    
    func transactionHistoryRecipientFilterPickerViewController(
        _ controller: TransactionHistoryRecipientFilterPickerViewController,
        didPickUsers users: [UserItem],
        addresses: [AddressItem]
    ) {
        filter.addresses = addresses
        recipientFilterView.reloadData(users: [], addresses: addresses)
        reloadData()
    }
    
}

extension Web3TransactionHistoryViewController: TransactionHistoryDatePickerViewControllerDelegate {
    
    func transactionHistoryDatePickerViewController(
        _ controller: TransactionHistoryDatePickerViewController,
        didPickStartDate startDate: Date?,
        endDate: Date?
    ) {
        filter.startDate = startDate
        filter.endDate = endDate
        dateFilterView.reloadData(startDate: startDate, endDate: endDate)
        filtersScrollView.layoutIfNeeded()
        let rightMost = CGPoint(x: filtersScrollView.contentSize.width - filtersScrollView.frame.width,
                                y: filtersScrollView.contentOffset.y)
        filtersScrollView.setContentOffset(rightMost, animated: false)
        reloadData()
    }
    
}

extension Web3TransactionHistoryViewController: Web3ReputationPickerViewController.Delegate {
    
    func web3ReputationPickerViewControllerDidResetOptions(
        _ controller: Web3ReputationPickerViewController
    ) {
        let options: Set<Web3Reputation.FilterOption> = filter.tokens
            .map(Web3Reputation.FilterOption.options(token:))
            .reduce(into: []) { result, options in
                result.formUnion(options)
            }
        filter.reputationOptions = options
        reputationFilterView.reloadData(options: options)
        filtersScrollView.layoutIfNeeded()
        reloadData()
    }
    
    func web3ReputationPickerViewController(
        _ controller: Web3ReputationPickerViewController,
        didPickOptions options: Set<Web3Reputation.FilterOption>
    ) {
        filter.reputationOptions = options
        reputationFilterView.reloadData(options: options)
        filtersScrollView.layoutIfNeeded()
        reloadData()
    }
    
}

extension Web3TransactionHistoryViewController {
    
    private func loadPreviousPage() {
        guard let firstItem else {
            Logger.general.debug(category: "TxnHistory", message: "No firstItem, abort loading")
            return
        }
        Logger.general.debug(category: "TxnHistory", message: "Will load before \(firstItem.id)")
        let operation = LoadLocalDataOperation(
            viewController: self,
            behavior: .prepend(offset: firstItem),
            filter: filter,
            order: order
        )
        queue.addOperation(operation)
    }
    
    private func loadNextPage() {
        guard let lastItem else {
            Logger.general.debug(category: "TxnHistory", message: "No lastItem, abort loading")
            return
        }
        Logger.general.debug(category: "TxnHistory", message: "Will load after \(lastItem.id)")
        let operation = LoadLocalDataOperation(
            viewController: self,
            behavior: .append(offset: lastItem),
            filter: filter,
            order: order
        )
        queue.addOperation(operation)
    }
    
}

extension Web3TransactionHistoryViewController {
    
    private final class TransactionHistoryReputationFilterView: TransactionHistoryFilterView {
        
        private weak var imageView: UIImageView?
        
        override func loadSubviews() {
            super.loadSubviews()
            let imageView = UIImageView()
            contentStackView.insertArrangedSubview(imageView, at: 0)
            self.imageView = imageView
            label.text = R.string.localizable.reputation()
        }
        
        func reloadData(options: Set<Web3Reputation.FilterOption>) {
            imageView?.image = if options.contains(.spam) {
                R.image.web3_reputation_bad()
            } else {
                R.image.web3_reputation_good()
            }
        }
        
    }
    
    private class LoadLocalDataOperation: Operation {
        
        enum Behavior: CustomDebugStringConvertible {
            
            // Full reload from the very first item
            case reload
            
            // Reload items after the offset. `offset` is included in the results
            case reloadVisibleItems(offset: Web3Transaction)
            
            // Load items before the offset. `offset` is not included
            case prepend(offset: Web3Transaction)
            
            // Load items after the offset. `offset` is not included
            case append(offset: Web3Transaction)
            
            var debugDescription: String {
                switch self {
                case .reload:
                    "reload"
                case .reloadVisibleItems(let offset):
                    "reloadVisibleItems(\(offset.id))"
                case .prepend(let offset):
                    "prepend(\(offset.id))"
                case .append(let offset):
                    "append(\(offset.id))"
                }
            }
            
        }
        
        private let walletID: String
        private let behavior: Behavior
        private let filter: Web3Transaction.Filter
        private let order: Web3Transaction.Order
        private let tokenSymbols: [String: String]
        
        private let limit = 50
        private let loadMoreThreshold = 5
        private let amountSortedSection = "" // There must be a section for items to insert
        
        private weak var viewController: Web3TransactionHistoryViewController?
        
        init(
            viewController: Web3TransactionHistoryViewController,
            behavior: Behavior,
            filter: Web3Transaction.Filter,
            order: Web3Transaction.Order
        ) {
            self.walletID = viewController.wallet.walletID
            self.behavior = behavior
            self.filter = filter
            self.order = order
            self.tokenSymbols = viewController.tokenSymbols
            self.viewController = viewController
            assert(limit > loadMoreThreshold)
        }
        
        override func main() {
            Logger.general.debug(category: "TxnLoader", message: "Load with behavior: \(behavior), filter: \(filter.description), order: \(order)")
            let offset: Web3TransactionDAO.Offset? = switch behavior {
            case .reload:
                    .none
            case .reloadVisibleItems(let offset):
                    .after(offset: offset, includesOffset: true)
            case .prepend(let offset):
                    .before(offset: offset, includesOffset: false)
            case .append(let offset):
                    .after(offset: offset, includesOffset: false)
            }
            
            let transactions = Web3TransactionDAO.shared.transactions(
                walletID: walletID,
                offset: offset,
                filter: filter,
                order: order,
                limit: limit
            )
            Logger.general.debug(category: "TxnLoader", message: "Loaded \(transactions.count) items:\n\(transactions.map(\.id))")
            
            var dataSnapshot: DataSourceSnapshot
            switch behavior {
            case .reload, .reloadVisibleItems:
                dataSnapshot = DataSourceSnapshot()
            case .prepend, .append:
                let snapshot = DispatchQueue.main.sync {
                    viewController?.dataSource.snapshot()
                }
                if let snapshot {
                    dataSnapshot = snapshot
                } else {
                    return
                }
            }
            
            switch offset {
            case .before:
                for transaction in transactions.reversed() {
                    let dateRepresentation: String = if let date = transaction.transactionAtDate {
                        DateFormatter.dateSimple.string(from: date)
                    } else {
                        transaction.transactionAt
                    }
                    if dataSnapshot.sectionIdentifiers.contains(dateRepresentation) {
                        if let firstItem = dataSnapshot.itemIdentifiers(inSection: dateRepresentation).first {
                            dataSnapshot.insertItems([transaction.id], beforeItem: firstItem)
                        } else {
                            dataSnapshot.appendItems([transaction.id], toSection: dateRepresentation)
                        }
                    } else {
                        if let firstSection = dataSnapshot.sectionIdentifiers.first {
                            dataSnapshot.insertSections([dateRepresentation], beforeSection: firstSection)
                        } else {
                            dataSnapshot.appendSections([dateRepresentation])
                        }
                        dataSnapshot.appendItems([transaction.id], toSection: dateRepresentation)
                    }
                }
            case .after, .none:
                for transaction in transactions {
                    let dateRepresentation: String = if let date = transaction.transactionAtDate {
                        DateFormatter.dateSimple.string(from: date)
                    } else {
                        transaction.transactionAt
                    }
                    if !dataSnapshot.sectionIdentifiers.reversed().contains(dateRepresentation) {
                        dataSnapshot.appendSections([dateRepresentation])
                    }
                    dataSnapshot.appendItems([transaction.id], toSection: dateRepresentation)
                }
            }
            
            var tokenSymbols = self.tokenSymbols
            var missingAssetIDs: Set<String> = []
            for transaction in transactions {
                let missingIDs = transaction.allAssetIDs.subtracting(tokenSymbols.keys)
                missingAssetIDs.formUnion(missingIDs)
            }
            if !missingAssetIDs.isEmpty {
                let symbols = Web3TokenDAO.shared.tokenSymbols(ids: missingAssetIDs)
                for (assetID, symbol) in symbols {
                    tokenSymbols[assetID] = TextTruncation.truncateTail(string: symbol, prefixCount: 8)
                }
            }
            
            DispatchQueue.main.sync {
                guard let controller = viewController, !isCancelled else {
                    return
                }
                controller.order = order
                switch behavior {
                case .reload, .reloadVisibleItems:
                    controller.items = transactions.reduce(into: [:]) { results, item in
                        results[item.id] = item
                    }
                case .prepend, .append:
                    for item in transactions {
                        controller.items[item.id] = item
                    }
                }
                controller.tokenSymbols = tokenSymbols
                switch behavior {
                case .reload:
                    controller.loadPreviousPageIndexPath = nil
                    controller.firstItem = nil
                    Logger.general.debug(category: "TxnLoader", message: "Going to table top by reloading")
                    controller.tableView.setContentOffset(.zero, animated: false)
                    controller.dataSource.applySnapshotUsingReloadData(dataSnapshot)
                case .reloadVisibleItems:
                    controller.withTableViewContentOffsetManaged {
                        if let item = transactions.first {
                            controller.loadPreviousPageIndexPath = IndexPath(row: 0, section: 0)
                            controller.firstItem = item
                            Logger.general.debug(category: "TxnLoader", message: "Set previous canary \(item.id)")
                        } else {
                            controller.loadPreviousPageIndexPath = nil
                            controller.firstItem = nil
                            Logger.general.debug(category: "TxnLoader", message: "Previous canary cleared")
                        }
                        controller.dataSource.applySnapshotUsingReloadData(dataSnapshot)
                    }
                case .prepend:
                    controller.withTableViewContentOffsetManaged {
                        if let item = transactions.first {
                            controller.loadPreviousPageIndexPath = IndexPath(row: 0, section: 0)
                            controller.firstItem = item
                            Logger.general.debug(category: "TxnLoader", message: "Set previous canary \(item.id)")
                        } else {
                            controller.loadPreviousPageIndexPath = nil
                            controller.firstItem = nil
                            Logger.general.debug(category: "TxnLoader", message: "Previous canary cleared")
                        }
                        controller.dataSource.apply(dataSnapshot, animatingDifferences: false)
                    }
                case .append:
                    controller.dataSource.apply(dataSnapshot, animatingDifferences: false)
                }
                controller.updateEmptyIndicator(numberOfItems: dataSnapshot.numberOfItems)
                switch behavior {
                case .prepend:
                    // Index path changes after prepending
                    if let lastItem = controller.lastItem {
                        controller.loadNextPageIndexPath = controller.dataSource.indexPath(for: lastItem.id)
                    }
                case .reload, .reloadVisibleItems, .append:
                    if transactions.count >= limit,
                       let canary = transactions.last,
                       let indexPath = controller.dataSource.indexPath(for: canary.id)
                    {
                        Logger.general.debug(category: "TxnLoader", message: "Set next canary \(canary.id)")
                        controller.loadNextPageIndexPath = indexPath
                        controller.lastItem = canary
                    } else {
                        Logger.general.debug(category: "TxnHistory", message: "Next canary cleared")
                        controller.loadNextPageIndexPath = nil
                        controller.lastItem = nil
                    }
                }
            }
        }
        
    }
    
}
