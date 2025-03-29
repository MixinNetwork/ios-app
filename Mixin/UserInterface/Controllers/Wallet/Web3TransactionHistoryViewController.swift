import UIKit
import MixinServices

final class Web3TransactionHistoryViewController: TransactionHistoryViewController {
    
    private typealias DateRepresentation = String
    private typealias TransactionID = String
    private typealias DiffableDataSource = UITableViewDiffableDataSource<DateRepresentation, TransactionID>
    private typealias DataSourceSnapshot = NSDiffableDataSourceSnapshot<DateRepresentation, TransactionID>
    
    private let walletID: String
    
    private var filter: Web3Transaction.Filter
    private var order: SafeSnapshot.Order = .newest
    private var dataSource: DiffableDataSource!
    private var items: [TransactionID: Web3TransactionItem] = [:]
    
    private var loadPreviousPageIndexPath: IndexPath?
    private var firstItem: Web3TransactionItem?
    
    private var loadNextPageIndexPath: IndexPath?
    private var lastItem: Web3TransactionItem?
    
    init(token: Web3TokenItem) {
        self.walletID = token.walletID
        self.filter = .init(tokens: [token])
        super.init()
    }
    
    init(walletID: String, type: Web3Transaction.TransactionType?) {
        self.walletID = walletID
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
        
        tableView.register(R.nib.snapshotCell)
        tableView.register(AssetHeaderView.self, forHeaderFooterViewReuseIdentifier: headerReuseIdentifier)
        tableView.delegate = self
        dataSource = DiffableDataSource(tableView: tableView) { [weak self] (tableView, indexPath, transactionID) in
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.snapshot, for: indexPath)!
            if let self {
                let snapshot = self.items[transactionID]!
                cell.render(transaction: snapshot)
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
        let job = SyncWeb3TransactionJob(walletID: walletID)
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
    @objc private func pickTokens(_ sender: Any) {
        let picker = Web3TransactionHistoryTokenFilterPickerViewController(selectedTokens: filter.tokens)
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
    
    private func typeFilterActions(selectedType type: Web3Transaction.TransactionType?) -> [UIAction] {
        [
            UIAction(
                title: R.string.localizable.all(),
                state: type == nil ? .on : .off,
                handler: { [weak self] _ in self?.reloadDataWithFilterType(nil) }
            ),
            UIAction(
                title: R.string.localizable.deposit(),
                image: R.image.filter_deposit(),
                state: type == .receive ? .on : .off,
                handler: { [weak self] _ in self?.reloadDataWithFilterType(.receive) }
            ),
            UIAction(
                title: R.string.localizable.withdrawal(),
                image: R.image.filter_withdrawal(),
                state: type == .send ? .on : .off,
                handler: { [weak self] _ in self?.reloadDataWithFilterType(.send) }
            ),
            UIAction(
                title: R.string.localizable.contract(),
                image: R.image.filter_contract(),
                state: type == .contract ? .on : .off,
                handler: { [weak self] _ in self?.reloadDataWithFilterType(.contract) }
            ),
        ]
    }
    
    private func reloadRightBarButtonItem(order: SafeSnapshot.Order) {
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
            UIAction(
                title: R.string.localizable.value(),
                image: R.image.order_value(),
                state: .off,
                handler: { [weak self] _ in self?.reloadDataWithOrder(.mostValuable) }
            ),
            UIAction(
                title: R.string.localizable.amount(),
                image: R.image.order_amount(),
                state: .off,
                handler: { [weak self] _ in self?.reloadDataWithOrder(.biggestAmount) }
            ),
        ]
        switch order {
        case .newest:
            actions[0].state = .on
        case .oldest:
            actions[1].state = .on
        case .mostValuable:
            actions[2].state = .on
        case .biggestAmount:
            actions[3].state = .on
        }
        rightBarButtonItem.menu = UIMenu(children: actions)
    }
    
    private func reloadDataWithFilterType(_ type: Web3Transaction.TransactionType?) {
        filter.type = type
        let actions = typeFilterActions(selectedType: filter.type)
        typeFilterView.button.menu = UIMenu(children: actions)
        typeFilterView.reloadData(type: type)
        reloadData()
    }
    
    private func reloadDataWithOrder(_ order: SafeSnapshot.Order) {
        self.order = order
        updateNavigationSubtitle(order: order)
        reloadRightBarButtonItem(order: order)
        reloadData()
    }
    
}

extension Web3TransactionHistoryViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch order {
        case .newest, .oldest:
            let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseIdentifier) as! AssetHeaderView
            view.label.text = dataSource.sectionIdentifier(for: section)
            return view
        case .mostValuable, .biggestAmount:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch order {
        case .newest, .oldest:
            44
        case .mostValuable, .biggestAmount:
            .leastNormalMagnitude
        }
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
        DispatchQueue.global().async { [weak self, walletID] in
            guard let token = Web3TokenDAO.shared.token(walletID: walletID, assetID: item.assetID) else {
                return
            }
            DispatchQueue.main.async {
                let viewController = Web3TransactionViewController(token: token, transaction: item)
                self?.navigationController?.pushViewController(viewController, animated: true)
            }
        }
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

extension Web3TransactionHistoryViewController {
    
    private func loadPreviousPage() {
        guard let firstItem else {
            Logger.general.debug(category: "TxnHistory", message: "No firstItem, abort loading")
            return
        }
        Logger.general.debug(category: "TxnHistory", message: "Will load before \(firstItem.transactionID)")
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
        Logger.general.debug(category: "TxnHistory", message: "Will load after \(lastItem.transactionID)")
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
    
    private class LoadLocalDataOperation: Operation {
        
        enum Behavior: CustomDebugStringConvertible {
            
            // Full reload from the very first item
            case reload
            
            // Reload items after the offset. `offset` is included in the results
            case reloadVisibleItems(offset: Web3TransactionItem)
            
            // Load items before the offset. `offset` is not included
            case prepend(offset: Web3TransactionItem)
            
            // Load items after the offset. `offset` is not included
            case append(offset: Web3TransactionItem)
            
            var debugDescription: String {
                switch self {
                case .reload:
                    "reload"
                case .reloadVisibleItems(let offset):
                    "reloadVisibleItems(\(offset.transactionID))"
                case .prepend(let offset):
                    "prepend(\(offset.transactionID))"
                case .append(let offset):
                    "append(\(offset.transactionID))"
                }
            }
            
        }
        
        private let behavior: Behavior
        private let filter: Web3Transaction.Filter
        private let order: SafeSnapshot.Order
        
        private let limit = 50
        private let loadMoreThreshold = 5
        private let amountSortedSection = "" // There must be a section for items to insert
        
        private weak var viewController: Web3TransactionHistoryViewController?
        
        init(
            viewController: Web3TransactionHistoryViewController?,
            behavior: Behavior,
            filter: Web3Transaction.Filter,
            order: SafeSnapshot.Order
        ) {
            self.viewController = viewController
            self.behavior = behavior
            self.filter = filter
            self.order = order
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
            
            let items = Web3TransactionDAO.shared.transactions(offset: offset, filter: filter, order: order, limit: limit)
            Logger.general.debug(category: "TxnLoader", message: "Loaded \(items.count) items:\n\(items.map(\.transactionID))")
            
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
            
            switch order {
            case .newest, .oldest:
                switch offset {
                case .before:
                    for item in items.reversed() {
                        let date = DateFormatter.dateSimple.string(from: item.createdAt.toUTCDate())
                        if dataSnapshot.sectionIdentifiers.contains(date) {
                            if let firstItem = dataSnapshot.itemIdentifiers(inSection: date).first {
                                dataSnapshot.insertItems([item.transactionID], beforeItem: firstItem)
                            } else {
                                dataSnapshot.appendItems([item.transactionID], toSection: date)
                            }
                        } else {
                            if let firstSection = dataSnapshot.sectionIdentifiers.first {
                                dataSnapshot.insertSections([date], beforeSection: firstSection)
                            } else {
                                dataSnapshot.appendSections([date])
                            }
                            dataSnapshot.appendItems([item.transactionID], toSection: date)
                        }
                    }
                case .after, .none:
                    for item in items {
                        let date = DateFormatter.dateSimple.string(from: item.createdAt.toUTCDate())
                        if !dataSnapshot.sectionIdentifiers.reversed().contains(date) {
                            dataSnapshot.appendSections([date])
                        }
                        dataSnapshot.appendItems([item.transactionID], toSection: date)
                    }
                }
            case .mostValuable, .biggestAmount:
                if dataSnapshot.numberOfSections == 0 {
                    dataSnapshot.appendSections([amountSortedSection])
                }
                switch offset {
                case .before:
                    let identifiers = items.map(\.transactionID)
                    if let firstIdentifier = dataSnapshot.itemIdentifiers.first {
                        dataSnapshot.insertItems(identifiers, beforeItem: firstIdentifier)
                    } else {
                        dataSnapshot.appendItems(identifiers, toSection: amountSortedSection)
                    }
                case .after, .none:
                    let identifiers = items.map(\.transactionID)
                    dataSnapshot.appendItems(identifiers, toSection: amountSortedSection)
                }
            }
            
            DispatchQueue.main.sync {
                guard let controller = viewController, !isCancelled else {
                    return
                }
                controller.order = order
                switch behavior {
                case .reload, .reloadVisibleItems:
                    controller.items = items.reduce(into: [:]) { results, item in
                        results[item.transactionID] = item
                    }
                case .prepend, .append:
                    for item in items {
                        controller.items[item.transactionID] = item
                    }
                }
                switch behavior {
                case .reload:
                    controller.loadPreviousPageIndexPath = nil
                    controller.firstItem = nil
                    Logger.general.debug(category: "TxnLoader", message: "Going to table top by reloading")
                    controller.tableView.setContentOffset(.zero, animated: false)
                    controller.dataSource.applySnapshotUsingReloadData(dataSnapshot)
                case .reloadVisibleItems:
                    controller.withTableViewContentOffsetManaged {
                        if let item = items.first {
                            controller.loadPreviousPageIndexPath = IndexPath(row: 0, section: 0)
                            controller.firstItem = item
                            Logger.general.debug(category: "TxnLoader", message: "Set previous canary \(item.transactionID)")
                        } else {
                            controller.loadPreviousPageIndexPath = nil
                            controller.firstItem = nil
                            Logger.general.debug(category: "TxnLoader", message: "Previous canary cleared")
                        }
                        controller.dataSource.applySnapshotUsingReloadData(dataSnapshot)
                    }
                case .prepend:
                    controller.withTableViewContentOffsetManaged {
                        if let item = items.first {
                            controller.loadPreviousPageIndexPath = IndexPath(row: 0, section: 0)
                            controller.firstItem = item
                            Logger.general.debug(category: "TxnLoader", message: "Set previous canary \(item.transactionID)")
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
                        controller.loadNextPageIndexPath = controller.dataSource.indexPath(for: lastItem.transactionID)
                    }
                case .reload, .reloadVisibleItems, .append:
                    if items.count >= limit,
                       let canary = items.last,
                       let indexPath = controller.dataSource.indexPath(for: canary.transactionID)
                    {
                        Logger.general.debug(category: "TxnLoader", message: "Set next canary \(canary.transactionID)")
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
