import UIKit
import MixinServices

class SafeSnapshotListViewController: UIViewController {
    
    enum DisplayFilter: CustomDebugStringConvertible {
        
        case token(id: String)
        case user(id: String)
        case address(assetID: String, address: String)
        
        var debugDescription: String {
            switch self {
            case let .token(id):
                "token: " + id
            case let .user(id):
                "user: " + id
            case let .address(_, address):
                "address: " + address
            }
        }
        
    }
    
    typealias DateRepresentation = String
    typealias SnapshotID = String
    typealias DiffableDataSource = UITableViewDiffableDataSource<DateRepresentation, SnapshotID>
    
    private typealias DataSourceSnapshot = NSDiffableDataSourceSnapshot<DateRepresentation, SnapshotID>
    
    let tableView = UITableView()
    
    var tokens: [String: TokenItem] = [:] // Key is asset id
    
    private(set) var dataSource: DiffableDataSource!
    private(set) var items: [SnapshotID: SafeSnapshotItem] = [:]
    
    private let headerReuseIdentifier = "header"
    private let displayFilter: DisplayFilter?
    private let queue = OperationQueue()
    
    private var sort: Snapshot.Sort = .createdAt
    private var sectionTitles: [DateRepresentation] = []
    
    private var loadPreviousPageIndexPath: IndexPath?
    private var firstItem: SafeSnapshotItem?
    
    private var loadNextPageIndexPath: IndexPath?
    private var lastItem: SafeSnapshotItem?
    
    init(displayFilter: DisplayFilter?) {
        self.displayFilter = displayFilter
        super.init(nibName: nil, bundle: nil)
        self.queue.maxConcurrentOperationCount = 1
        self.dataSource = DiffableDataSource(tableView: tableView) { [weak self] (tableView, indexPath, snapshotID) in
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.snapshot, for: indexPath)!
            if let self {
                let snapshot = self.items[snapshotID]!
                let token = self.tokens[snapshot.assetID]
                cell.render(snapshot: snapshot, token: token)
                cell.delegate = self as? SnapshotCellDelegate
            }
            return cell
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(tableView)
        tableView.backgroundColor = R.color.background()!
        tableView.snp.makeEdgesEqualToSuperview()
        tableView.register(R.nib.snapshotCell)
        tableView.register(AssetHeaderView.self, forHeaderFooterViewReuseIdentifier: headerReuseIdentifier)
        tableView.rowHeight = 62
        tableView.separatorStyle = .none
        tableView.delegate = self
        
        reloadData(with: .createdAt)
        NotificationCenter.default.addObserver(self, selector: #selector(snapshotsDidSave(_:)), name: SafeSnapshotDAO.snapshotDidSaveNotification, object: nil)
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        if view.safeAreaInsets.bottom < 1 {
            tableView.contentInset.bottom = 10
        } else {
            tableView.contentInset.bottom = 0
        }
    }
    
    func reloadData(with sort: Snapshot.Sort) {
        queue.cancelAllOperations()
        let operation = LoadLocalDataOperation(viewController: self,
                                               behavior: .reload,
                                               filter: displayFilter,
                                               sort: sort)
        queue.addOperation(operation)
    }
    
    func updateEmptyIndicator(numberOfItems: Int) {
        tableView.checkEmpty(dataCount: numberOfItems,
                             text: R.string.localizable.no_transactions(),
                             photo: R.image.emptyIndicator.ic_data()!)
    }
    
}

extension SafeSnapshotListViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch sort {
        case .createdAt:
            let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseIdentifier) as! AssetHeaderView
            if #available(iOS 15.0, *) {
                view.label.text = dataSource.sectionIdentifier(for: section)
            } else {
                view.label.text = sectionTitles[section]
            }
            return view
        case .amount:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch sort {
        case .createdAt:
            44
        case .amount:
            .leastNormalMagnitude
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        switch indexPath {
        case loadPreviousPageIndexPath:
            loadPreviousPageIndexPath = nil
            loadPreviousPage()
        case loadNextPageIndexPath:
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
        if let token = tokens[item.assetID] {
            let viewController = SnapshotViewController.instance(token: token, snapshot: item)
            navigationController?.pushViewController(viewController, animated: true)
        } else {
            DispatchQueue.global().async { [weak self] in
                if let inscriptionHash = item.inscriptionHash {
                    guard let inscription = InscriptionDAO.shared.inscriptionItem(with: inscriptionHash) else {
                        return
                    }
                    DispatchQueue.main.async {
                        let viewController = InscriptionViewController.instance(inscription: inscription, snapshot: item)
                        self?.navigationController?.pushViewController(viewController, animated: true)
                    }
                } else {
                    guard let token = TokenDAO.shared.tokenItem(with: item.assetID) else {
                        return
                    }
                    DispatchQueue.main.async {
                        let viewController = SnapshotViewController.instance(token: token, snapshot: item)
                        self?.navigationController?.pushViewController(viewController, animated: true)
                    }
                }
            }
        }
    }
    
}

extension SafeSnapshotListViewController {
    
    @objc private func snapshotsDidSave(_ notification: Notification) {
        if let snapshots = notification.userInfo?[SafeSnapshotDAO.snapshotsUserInfoKey] as? [SafeSnapshot], snapshots.count == 1 {
            let snapshot = snapshots[0]
            let isSnapshotAssociated = switch displayFilter {
            case .token(let id):
                snapshot.assetID == id
            case .user(let id):
                snapshot.opponentID == id
            case let .address(assetID, address):
                snapshot.assetID == assetID && (snapshot.deposit?.sender == address || snapshot.withdrawal?.receiver == address)
            case nil:
                true
            }
            if !isSnapshotAssociated {
                // The snapshot will never show in this view, no need to load
                return
            }
            if items[snapshot.id] != nil {
                // If there's only 1 item is saved, reduce db access by reloading it in place
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
        let operation = LoadLocalDataOperation(viewController: self,
                                               behavior: behavior,
                                               filter: displayFilter,
                                               sort: sort)
        queue.addOperation(operation)
    }
    
    private func loadPreviousPage() {
        guard let firstItem else {
            return
        }
        let operation = LoadLocalDataOperation(viewController: self,
                                               behavior: .prepend(offset: firstItem),
                                               filter: displayFilter,
                                               sort: sort)
        queue.addOperation(operation)
    }
    
    private func loadNextPage() {
        guard let lastItem else {
            return
        }
        let operation = LoadLocalDataOperation(viewController: self,
                                               behavior: .append(offset: lastItem),
                                               filter: displayFilter,
                                               sort: sort)
        queue.addOperation(operation)
    }
    
    private func withTableViewContentOffsetManaged(_ block: () -> Void) {
        var tableBottomContentOffsetY: CGFloat {
            tableView.adjustedContentInset.vertical + tableView.contentSize.height - tableView.frame.height
        }
        
        let contentSizeBefore = tableView.contentSize
        let wasAtTableTop = tableView.contentOffset.y < 1
        let wasAtTableBottom = abs(tableView.contentOffset.y - tableBottomContentOffsetY) < 1
        block()
        view.layoutIfNeeded() // Important, ensures `tableView.contentSize` is correct
        let contentOffset: CGPoint
        if wasAtTableTop {
            contentOffset = .zero
        } else if wasAtTableBottom {
            contentOffset = CGPoint(x: 0, y: tableBottomContentOffsetY)
        } else {
            let contentSizeAfter = tableView.contentSize
            let y = max(tableView.contentOffset.y, tableView.contentOffset.y + contentSizeAfter.height - contentSizeBefore.height)
            contentOffset = CGPoint(x: tableView.contentOffset.x, y: y)
        }
        tableView.setContentOffset(contentOffset, animated: false)
    }
    
}

extension SafeSnapshotListViewController {
    
    private class ReloadSingleItemOperation: Operation {
        
        private let snapshotID: String
        
        private weak var viewController: SafeSnapshotListViewController?
        
        init(viewController: SafeSnapshotListViewController?, snapshotID: String) {
            self.viewController = viewController
            self.snapshotID = snapshotID
        }
        
        override func main() {
            guard let item = SafeSnapshotDAO.shared.snapshotItem(id: snapshotID) else {
                return
            }
            Logger.general.debug(category: "SnapshotListLoader", message: "Start reloading id: \(snapshotID)")
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
                    "reloadVisibleItems(\(offset.amount) \(offset.tokenSymbol ?? "") \(offset.createdAt))"
                case .prepend(let offset):
                    "prepend(\(offset.amount) \(offset.tokenSymbol ?? "") \(offset.createdAt))"
                case .append(let offset):
                    "append(\(offset.amount) \(offset.tokenSymbol ?? "") \(offset.createdAt))"
                }
            }
            
        }
        
        private let behavior: Behavior
        private let filter: DisplayFilter?
        private let sort: Snapshot.Sort
        
        private let limit = 50
        private let loadMoreThreshold = 5
        private let amountSortedSection = ""
        
        private weak var viewController: SafeSnapshotListViewController?
        
        init(
            viewController: SafeSnapshotListViewController?,
            behavior: Behavior,
            filter: DisplayFilter?,
            sort: Snapshot.Sort
        ) {
            self.viewController = viewController
            self.behavior = behavior
            self.filter = filter
            self.sort = sort
            assert(limit > loadMoreThreshold)
        }
        
        override func main() {
            Logger.general.debug(category: "SnapshotListLoader", message: "Start loading with behavior: \(behavior), filter: \(filter?.debugDescription ?? "none"), sort: \(sort)")
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
            
            let items: [SafeSnapshotItem] = switch filter {
            case let .token(id):
                SafeSnapshotDAO.shared.snapshots(assetId: id, offset: offset, sort: sort, limit: limit)
            case let .user(id):
                SafeSnapshotDAO.shared.snapshots(opponentID: id, offset: offset, sort: sort, limit: limit)
            case let .address(assetID, address):
                SafeSnapshotDAO.shared.snapshots(assetID: assetID, address: address, offset: offset, sort: sort, limit: limit)
            case .none:
                SafeSnapshotDAO.shared.snapshots(offset: offset, sort: sort, limit: limit)
            }
            refreshUserIfNeeded(items)
            
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
            
            switch sort {
            case .createdAt:
                switch offset {
                case .before:
                    for item in items {
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
            case .amount:
                if dataSnapshot.numberOfSections == 0 {
                    dataSnapshot.appendSections([amountSortedSection])
                }
                switch offset {
                case .before:
                    let identifiers = items.reversed().map(\.id)
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
                controller.sort = sort
                controller.sectionTitles = dataSnapshot.sectionIdentifiers
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
                    if #available(iOS 15.0, *) {
                        controller.dataSource.applySnapshotUsingReloadData(dataSnapshot)
                    } else {
                        controller.dataSource.apply(dataSnapshot, animatingDifferences: false)
                    }
                case .reloadVisibleItems:
                    controller.withTableViewContentOffsetManaged {
                        controller.loadPreviousPageIndexPath = IndexPath(row: 0, section: 0)
                        controller.firstItem = items.first
                        if #available(iOS 15.0, *) {
                            controller.dataSource.applySnapshotUsingReloadData(dataSnapshot)
                        } else {
                            controller.dataSource.apply(dataSnapshot, animatingDifferences: false)
                        }
                    }
                case .prepend:
                    controller.withTableViewContentOffsetManaged {
                        controller.loadPreviousPageIndexPath = IndexPath(row: 0, section: 0)
                        controller.firstItem = items.last // `items` are inserted in reversed order
                        controller.dataSource.apply(dataSnapshot, animatingDifferences: false)
                    }
                case .append:
                    controller.dataSource.apply(dataSnapshot, animatingDifferences: false)
                }
                controller.updateEmptyIndicator(numberOfItems: dataSnapshot.numberOfItems)
                switch behavior {
                case .prepend:
                    break
                case .reload, .reloadVisibleItems, .append:
                    if items.count >= limit {
                        let canary = items[items.count - loadMoreThreshold]
                        controller.loadNextPageIndexPath = controller.dataSource.indexPath(for: canary.id)
                    } else {
                        controller.loadNextPageIndexPath = nil
                    }
                    controller.lastItem = items.last
                }
            }
        }
        
        private func refreshUserIfNeeded(_ snapshots: [SafeSnapshotItem]) {
            var userIDs: Set<String> = []
            for snapshot in snapshots {
                if let userID = snapshot.opponentUserID {
                    userIDs.insert(userID)
                }
            }
            let inexistedUserIDs = userIDs.filter { id in
                !UserDAO.shared.isExist(userId: id)
            }
            if !inexistedUserIDs.isEmpty {
                let job = RefreshUserJob(userIds: Array(inexistedUserIDs))
                ConcurrentJobQueue.shared.addJob(job: job)
            }
        }
        
    }
    
}
