import UIKit
import MixinServices

final class MixinTransactionHistoryViewController: TransactionHistoryViewController {
    
    private typealias DateRepresentation = String
    private typealias SnapshotID = String
    private typealias DiffableDataSource = UITableViewDiffableDataSource<DateRepresentation, SnapshotID>
    private typealias DataSourceSnapshot = NSDiffableDataSourceSnapshot<DateRepresentation, SnapshotID>
    
    private var filter: SafeSnapshot.Filter
    private var order: SafeSnapshot.Order = .newest
    private var dataSource: DiffableDataSource!
    private var items: [SnapshotID: SafeSnapshotItem] = [:]
    
    private var loadPreviousPageIndexPath: IndexPath?
    private var firstItem: SafeSnapshotItem?
    
    private var loadNextPageIndexPath: IndexPath?
    private var lastItem: SafeSnapshotItem?
    
    init(token: MixinTokenItem) {
        self.filter = .init(tokens: [token])
        super.init()
    }
    
    init(user: UserItem) {
        self.filter = .init(users: [user])
        super.init()
    }
    
    init(address: AddressItem) {
        self.filter = .init(addresses: [address])
        super.init()
    }
    
    init(type: SafeSnapshot.DisplayType?) {
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
        recipientFilterView.reloadData(users: filter.users, addresses: filter.addresses)
        recipientFilterView.button.addTarget(self, action: #selector(pickRecipients(_:)), for: .touchUpInside)
        dateFilterView.reloadData(startDate: filter.startDate, endDate: filter.endDate)
        dateFilterView.button.addTarget(self, action: #selector(pickDates(_:)), for: .touchUpInside)
        
        tableView.register(R.nib.snapshotCell)
        tableView.register(AssetHeaderView.self, forHeaderFooterViewReuseIdentifier: headerReuseIdentifier)
        tableView.delegate = self
        dataSource = DiffableDataSource(tableView: tableView) { [weak self] (tableView, indexPath, snapshotID) in
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.snapshot, for: indexPath)!
            if let self {
                let snapshot = self.items[snapshotID]!
                cell.render(snapshot: snapshot)
            }
            return cell
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(snapshotsDidSave(_:)), name: SafeSnapshotDAO.snapshotDidSaveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(inscriptionDidRefresh(_:)), name: RefreshInscriptionJob.didFinishNotification, object: nil)
        reloadData()
    }
    
    @objc private func pickTokens(_ sender: Any) {
        let picker = MixinTransactionHistoryTokenFilterPickerViewController(selectedTokens: filter.tokens)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc private func pickRecipients(_ sender: Any) {
        let picker: TransactionHistoryRecipientFilterPickerViewController
        switch filter.type {
        case .none:
            picker = .init(segments: [.user, .address], users: filter.users, addresses: filter.addresses)
        case .deposit, .withdrawal, .pending:
            picker = .init(segments: [.address], users: [], addresses: filter.addresses)
        case .transfer:
            picker = .init(segments: [.user], users: filter.users, addresses: filter.addresses)
        }
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc private func pickDates(_ sender: Any) {
        let picker = TransactionHistoryDatePickerViewController(startDate: filter.startDate, endDate: filter.endDate)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    private func updateNavigationSubtitle(order: SafeSnapshot.Order) {
        guard let titleView = navigationItem.titleView as? NavigationTitleView else {
            return
        }
        titleView.subtitle = switch order {
        case .newest:
            R.string.localizable.sort_by_recent()
        case .oldest:
            R.string.localizable.sort_by_oldest()
        case .mostValuable:
            R.string.localizable.sort_by_value()
        case .biggestAmount:
            R.string.localizable.sort_by_amount()
        }
    }
    
    private func orderActions(selectedOrder order: SafeSnapshot.Order) -> [UIAction] {
        let actions = [
            UIAction(
                title: R.string.localizable.recent(),
                image: R.image.order_newest(),
                state: .off,
                handler: { [weak self] _ in self?.reloadData(order: .newest) }
            ),
            UIAction(
                title: R.string.localizable.oldest(),
                image: R.image.order_oldest(),
                state: .off,
                handler: { [weak self] _ in self?.reloadData(order: .oldest) }
            ),
            UIAction(
                title: R.string.localizable.value(),
                image: R.image.order_value(),
                state: .off,
                handler: { [weak self] _ in self?.reloadData(order: .mostValuable) }
            ),
            UIAction(
                title: R.string.localizable.amount(),
                image: R.image.order_amount(),
                state: .off,
                handler: { [weak self] _ in self?.reloadData(order: .biggestAmount) }
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
        return actions
    }
    
    private func typeFilterActions(selectedType type: SafeSnapshot.DisplayType?) -> [UIAction] {
        let actions = [
            UIAction(
                title: R.string.localizable.all(),
                state: .off,
                handler: { [weak self] _ in self?.reloadData(filterType: nil) }
            ),
            UIAction(
                title: R.string.localizable.deposit(),
                image: R.image.filter_deposit(),
                state: .off,
                handler: { [weak self] _ in self?.reloadData(filterType: .deposit) }
            ),
            UIAction(
                title: R.string.localizable.withdrawal(),
                image: R.image.filter_withdrawal(),
                state: .off,
                handler: { [weak self] _ in self?.reloadData(filterType: .withdrawal) }
            ),
            UIAction(
                title: R.string.localizable.transfer(),
                image: R.image.filter_transfer(),
                state: .off,
                handler: { [weak self] _ in self?.reloadData(filterType: .transfer) }
            ),
            UIAction(
                title: R.string.localizable.pending(),
                image: R.image.filter_pending(),
                state: .off,
                handler: { [weak self] _ in self?.reloadData(filterType: .pending) }
            ),
        ]
        switch type {
        case .none:
            actions[0].state = .on
        case .deposit:
            actions[1].state = .on
        case .withdrawal:
            actions[2].state = .on
        case .transfer:
            actions[3].state = .on
        case .pending:
            actions[4].state = .on
        }
        return actions
    }
    
    private func reloadRightBarButtonItem(order: SafeSnapshot.Order) {
        let rightBarButtonItem: UIBarButtonItem
        if let item = navigationItem.rightBarButtonItem {
            rightBarButtonItem = item
        } else {
            rightBarButtonItem = .tintedIcon(image: R.image.navigation_filter(), target: nil, action: nil)
            navigationItem.rightBarButtonItem = rightBarButtonItem
        }
        let actions = orderActions(selectedOrder: order)
        rightBarButtonItem.menu = UIMenu(children: actions)
    }
    
    private func reloadData(filterType type: SafeSnapshot.DisplayType?) {
        filter.type = type
        let actions = typeFilterActions(selectedType: filter.type)
        typeFilterView.button.menu = UIMenu(children: actions)
        typeFilterView.reloadData(type: type)
        reloadData()
    }
    
    private func reloadData(order: SafeSnapshot.Order) {
        self.order = order
        updateNavigationSubtitle(order: order)
        reloadRightBarButtonItem(order: order)
        reloadData()
    }
    
    private func reloadData() {
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

extension MixinTransactionHistoryViewController: UITableViewDelegate {
    
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
        DispatchQueue.global().async { [weak self] in
            guard let token = TokenDAO.shared.tokenItem(assetID: item.assetID) else {
                return
            }
            let inscriptionItem: InscriptionItem? = if let hash = item.inscriptionHash {
                InscriptionDAO.shared.inscriptionItem(with: hash)
            } else {
                nil
            }
            DispatchQueue.main.async {
                let viewController = SafeSnapshotViewController(
                    token: token,
                    snapshot: item,
                    messageID: nil,
                    inscription: inscriptionItem
                )
                self?.navigationController?.pushViewController(viewController, animated: true)
            }
        }
    }
    
}

extension MixinTransactionHistoryViewController: MixinTransactionHistoryTokenFilterPickerViewControllerDelegate {
    
    func mixinTransactionHistoryTokenFilterPickerViewController(
        _ controller: MixinTransactionHistoryTokenFilterPickerViewController,
        didPickTokens tokens: [MixinTokenItem]
    ) {
        filter.tokens = tokens
        assetFilterView.reloadData(tokens: tokens)
        reloadData()
    }
    
}

extension MixinTransactionHistoryViewController: TransactionHistoryRecipientFilterPickerViewControllerDelegate {
    
    func transactionHistoryRecipientFilterPickerViewController(
        _ controller: TransactionHistoryRecipientFilterPickerViewController,
        didPickUsers users: [UserItem],
        addresses: [AddressItem]
    ) {
        filter.users = users
        filter.addresses = addresses
        recipientFilterView.reloadData(users: users, addresses: addresses)
        reloadData()
    }
    
}

extension MixinTransactionHistoryViewController: TransactionHistoryDatePickerViewControllerDelegate {
    
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

extension MixinTransactionHistoryViewController {
    
    @objc private func snapshotsDidSave(_ notification: Notification) {
        if let snapshots = notification.userInfo?[SafeSnapshotDAO.snapshotsUserInfoKey] as? [SafeSnapshot], snapshots.count == 1 {
            // If there's only 1 item is saved, reduce db access by reloading it in place
            let snapshot = snapshots[0]
            if !filter.isIncluded(snapshot: snapshot) {
                // The snapshot will never show in this view, no need to load
                return
            }
            if items[snapshot.id] != nil {
                let operation = ReloadSingleItemOperation(viewController: self, snapshotID: snapshots[0].id)
                queue.addOperation(operation)
                return
            }
        }
        let behavior: LoadLocalDataOperation.Behavior
        if let firstVisibleCell = tableView.visibleCells.first,
           let firstVisibleIndexPath = tableView.indexPath(for: firstVisibleCell),
           let snapshotID = dataSource.itemIdentifier(for: firstVisibleIndexPath),
           let firstItem = items[snapshotID]
        {
            behavior = .reloadVisibleItems(offset: firstItem)
        } else {
            behavior = .reload
        }
        Logger.general.debug(category: "TxnHistory", message: "Previous canary cleared")
        loadPreviousPageIndexPath = nil
        Logger.general.debug(category: "TxnHistory", message: "Next canary cleared")
        loadNextPageIndexPath = nil
        let operation = LoadLocalDataOperation(
            viewController: self,
            behavior: behavior,
            filter: filter,
            order: order
        )
        queue.addOperation(operation)
    }
    
    @objc private func inscriptionDidRefresh(_ notification: Notification) {
        guard let snapshotID = notification.userInfo?[RefreshInscriptionJob.UserInfoKey.snapshotID] as? String else {
            return
        }
        if items[snapshotID] != nil {
            let operation = ReloadSingleItemOperation(viewController: self, snapshotID: snapshotID)
            queue.addOperation(operation)
        }
    }
    
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

extension MixinTransactionHistoryViewController {
    
    private class ReloadSingleItemOperation: Operation {
        
        private let snapshotID: String
        
        private weak var viewController: MixinTransactionHistoryViewController?
        
        init(viewController: MixinTransactionHistoryViewController?, snapshotID: String) {
            self.viewController = viewController
            self.snapshotID = snapshotID
        }
        
        override func main() {
            guard let item = SafeSnapshotDAO.shared.snapshotItem(id: snapshotID) else {
                return
            }
            Logger.general.debug(category: "TxnLoader", message: "Reload id: \(snapshotID)")
            DispatchQueue.main.sync {
                guard let viewController, !isCancelled else {
                    return
                }
                viewController.items[item.id] = item
                var dataSnapshot = viewController.dataSource.snapshot()
                dataSnapshot.reloadItems([item.id])
                viewController.dataSource.apply(dataSnapshot, animatingDifferences: false)
            }
        }
        
    }
    
    private class LoadLocalDataOperation: Operation {
        
        enum Behavior: CustomDebugStringConvertible {
            
            // Full reload from the very first item
            case reload
            
            // Reload items after the offset. `offset` is included in the results
            case reloadVisibleItems(offset: SafeSnapshotItem)
            
            // Load items before the offset. `offset` is not included
            case prepend(offset: SafeSnapshotItem)
            
            // Load items after the offset. `offset` is not included
            case append(offset: SafeSnapshotItem)
            
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
        
        private let behavior: Behavior
        private let filter: SafeSnapshot.Filter
        private let order: SafeSnapshot.Order
        
        private let limit = 50
        private let loadMoreThreshold = 5
        private let amountSortedSection = "" // There must be a section for items to insert
        
        private weak var viewController: MixinTransactionHistoryViewController?
        
        init(
            viewController: MixinTransactionHistoryViewController?,
            behavior: Behavior,
            filter: SafeSnapshot.Filter,
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
            let offset: SafeSnapshotDAO.Offset? = switch behavior {
            case .reload:
                    .none
            case .reloadVisibleItems(let offset):
                    .after(offset: offset, includesOffset: true)
            case .prepend(let offset):
                    .before(offset: offset, includesOffset: false)
            case .append(let offset):
                    .after(offset: offset, includesOffset: false)
            }
            
            let items = SafeSnapshotDAO.shared.snapshots(offset: offset, filter: filter, order: order, limit: limit)
            loadMissingUsersOrTokens(items)
            Logger.general.debug(category: "TxnLoader", message: "Loaded \(items.count) items:\n\(items.map(\.id))")
            
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
                                dataSnapshot.insertItems([item.id], beforeItem: firstItem)
                            } else {
                                dataSnapshot.appendItems([item.id], toSection: date)
                            }
                        } else {
                            if let firstSection = dataSnapshot.sectionIdentifiers.first {
                                dataSnapshot.insertSections([date], beforeSection: firstSection)
                            } else {
                                dataSnapshot.appendSections([date])
                            }
                            dataSnapshot.appendItems([item.id], toSection: date)
                        }
                    }
                case .after, .none:
                    for item in items {
                        let date = DateFormatter.dateSimple.string(from: item.createdAt.toUTCDate())
                        if !dataSnapshot.sectionIdentifiers.reversed().contains(date) {
                            dataSnapshot.appendSections([date])
                        }
                        dataSnapshot.appendItems([item.id], toSection: date)
                    }
                }
            case .mostValuable, .biggestAmount:
                if dataSnapshot.numberOfSections == 0 {
                    dataSnapshot.appendSections([amountSortedSection])
                }
                switch offset {
                case .before:
                    let identifiers = items.map(\.id)
                    if let firstIdentifier = dataSnapshot.itemIdentifiers.first {
                        dataSnapshot.insertItems(identifiers, beforeItem: firstIdentifier)
                    } else {
                        dataSnapshot.appendItems(identifiers, toSection: amountSortedSection)
                    }
                case .after, .none:
                    let identifiers = items.map(\.id)
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
                        results[item.id] = item
                    }
                case .prepend, .append:
                    for item in items {
                        controller.items[item.id] = item
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
                        if let item = items.first {
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
                    if items.count >= limit,
                       let canary = items.last,
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
        
        private func loadMissingUsersOrTokens(_ snapshots: [SafeSnapshotItem]) {
            var userIDs: Set<String> = []
            var missingAssetIDs: Set<String> = []
            for snapshot in snapshots {
                if let userID = snapshot.opponentUserID {
                    userIDs.insert(userID)
                }
                if snapshot.tokenSymbol == nil {
                    missingAssetIDs.insert(snapshot.assetID)
                }
            }
            
            let missingUserIDs = userIDs.filter { id in
                !UserDAO.shared.isExist(userId: id)
            }
            if !missingUserIDs.isEmpty {
                let job = RefreshUserJob(userIds: Array(missingUserIDs))
                ConcurrentJobQueue.shared.addJob(job: job)
            }
            
            for id in missingAssetIDs {
                let job = RefreshTokenJob(assetID: id)
                ConcurrentJobQueue.shared.addJob(job: job)
            }
        }
        
    }
    
}
