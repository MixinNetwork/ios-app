import UIKit
import MixinServices

final class SwapOrderTableViewController: UIViewController {
    
    fileprivate typealias DateRepresentation = String
    fileprivate typealias OrderID = String
    fileprivate typealias DiffableDataSource = UITableViewDiffableDataSource<DateRepresentation, OrderID>
    fileprivate typealias DataSourceSnapshot = NSDiffableDataSourceSnapshot<DateRepresentation, OrderID>
    
    private let localPageCount = 50
    private let remotePageCount = 100
    private let headerReuseIdentifier = "h"
    private let queue = DispatchQueue(label: "one.mixin.messenger.SwapOrderLoading")
    
    private var tableView: UITableView!
    private var dataSource: DiffableDataSource!
    private var items: [OrderID: SwapOrderItem] = [:]
    private var loadNextPageIndexPath: IndexPath?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        BadgeManager.shared.setHasViewed(identifier: .swapOrder)
        title = R.string.localizable.orders()
        navigationItem.titleView = WalletIdentifyingNavigationTitleView(
            title: R.string.localizable.orders(),
            wallet: .privacy
        )
        view.backgroundColor = R.color.background()
        
        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.backgroundColor = R.color.background()
        tableView.register(R.nib.swapOrderCell)
        tableView.register(HeaderView.self, forHeaderFooterViewReuseIdentifier: headerReuseIdentifier)
        tableView.estimatedRowHeight = 85
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.delegate = self
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        
        dataSource = DiffableDataSource(tableView: tableView) { [weak self] (tableView, indexPath, orderID) in
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.swap_order, for: indexPath)!
            if let order = self?.items[orderID] {
                cell.load(order: order)
            }
            return cell
        }
        tableView.dataSource = dataSource
        updateTableViewContentInsetBottom()
        
        queue.async { [limit=localPageCount] in
            let orders = SwapOrderDAO.shared.orders(limit: limit)
            let offset = SwapOrderDAO.shared.oldestPendingOrFailedOrderCreatedAt()
            let snapshot = DataSourceSnapshot(orders: orders)
            DispatchQueue.main.sync { [weak self] in
                guard let self else {
                    return
                }
                if let newestOrder = orders.first {
                    for order in orders {
                        self.items[order.orderID] = order
                    }
                    if orders.count == limit {
                        self.resetLoadNextPageIndexPath(snapshot: snapshot)
                    }
                    self.dataSource.applySnapshotUsingReloadData(snapshot)
                    let offset = offset ?? newestOrder.createdAt
                    self.reloadRemoteOrders(offset: offset)
                } else {
                    self.tableView.checkEmpty(
                        dataCount: 0,
                        text: R.string.localizable.no_orders(),
                        photo: R.image.emptyIndicator.ic_data()!
                    )
                    self.reloadRemoteOrders(offset: nil)
                }
            }
        }
        
        reporter.report(event: .tradeTransactions)
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTableViewContentInsetBottom()
    }
    
    private func updateTableViewContentInsetBottom() {
        if view.safeAreaInsets.bottom > 10 {
            tableView.contentInset.bottom = 0
        } else {
            tableView.contentInset.bottom = 10
        }
    }
    
}

extension SwapOrderTableViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath == loadNextPageIndexPath,
           let orderID = dataSource.itemIdentifier(for: indexPath),
           let offset = items[orderID]
        {
            loadNextPageIndexPath = nil
            queue.async { [limit=localPageCount, weak self] in
                guard let self else {
                    return
                }
                Logger.general.info(category: "SwapOrderTable", message: "Loading local orders before \(offset.createdAt)")
                let orders = SwapOrderDAO.shared.orders(before: offset.createdAt, limit: limit)
                guard let oldestOrder = orders.last, let newestOrder = orders.first else {
                    Logger.general.info(category: "SwapOrderTable", message: "All local orders loaded")
                    return
                }
                var snapshot = DispatchQueue.main.sync {
                    self.dataSource.snapshot()
                }
                for order in orders {
                    guard let createdAtDate = order.createdAtDate else {
                        continue
                    }
                    let date = DateFormatter.dateSimple.string(from: createdAtDate)
                    if !snapshot.sectionIdentifiers.reversed().contains(date) {
                        snapshot.appendSections([date])
                    }
                    snapshot.appendItems([order.orderID], toSection: date)
                }
                Logger.general.info(category: "SwapOrderTable", message: "Appended \(orders.count) local orders, range: \(newestOrder.createdAt) ~ \(oldestOrder.createdAt)")
                DispatchQueue.main.sync {
                    for order in orders {
                        self.items[order.orderID] = order
                    }
                    if orders.count == limit {
                        self.resetLoadNextPageIndexPath(snapshot: snapshot)
                    }
                    self.dataSource.apply(snapshot, animatingDifferences: false)
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseIdentifier) as! HeaderView
        header.label.text = dataSource.sectionIdentifier(for: section)
        return header
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let id = dataSource.itemIdentifier(for: indexPath), let item = items[id] {
            let details = SwapOrderViewController(order: item)
            navigationController?.pushViewController(details, animated: true)
        }
    }
    
}

extension SwapOrderTableViewController {
    
    private final class HeaderView: GeneralTableViewHeader {
        
        override func prepare() {
            super.prepare()
            label.setFont(scaledFor: .systemFont(ofSize: 12), adjustForContentSize: true)
            label.textColor = UIColor(displayP3RgbValue: 0xBCBEC3, alpha: 1)
            labelTopConstraint.constant = 20
            labelBottomConstraint.constant = -10
        }
        
    }
    
    private func resetLoadNextPageIndexPath(snapshot: DataSourceSnapshot) {
        guard let lastSectionIdentifier = snapshot.sectionIdentifiers.last else {
            loadNextPageIndexPath = nil
            return
        }
        let section = snapshot.numberOfSections - 1
        let row = snapshot.numberOfItems(inSection: lastSectionIdentifier) - 1
        loadNextPageIndexPath = IndexPath(row: row, section: section)
    }
    
    private func reloadRemoteOrders(offset: String?) {
        Logger.general.info(category: "SwapOrderTable", message: "Loading remote orders from \(offset ?? "beginning")")
        let remotePageCount = self.remotePageCount
        let localPageCount = self.localPageCount
        RouteAPI.mixinSwapOrders(
            offset: offset,
            limit: remotePageCount,
            queue: .global()
        ) { [weak self] result in
            switch result {
            case .success(let remoteOrders):
                guard let oldestOrder = remoteOrders.first, let newestOrder = remoteOrders.last else {
                    Logger.general.info(category: "SwapOrderTable", message: "All remote orders loaded")
                    return
                }
                Logger.general.info(category: "SwapOrderTable", message: "Loaded \(remoteOrders.count) remote orders \(oldestOrder.createdAt) ~ \(newestOrder.createdAt)")
                
                let didFinish = remoteOrders.count < remotePageCount
                SwapOrderDAO.shared.save(orders: remoteOrders)
                
                let orderAssetIDs = Set(remoteOrders.flatMap({ order in
                    [order.payAssetID, order.receiveAssetID]
                }))
                let inexistsAssetIDs = TokenDAO.shared.inexistAssetIDs(in: orderAssetIDs)
                if !inexistsAssetIDs.isEmpty, case let .success(tokens) = SafeAPI.assets(ids: inexistsAssetIDs) {
                    TokenDAO.shared.save(assets: tokens)
                }
                
                let localOrders = SwapOrderDAO.shared.orders(limit: localPageCount)
                let snapshot = DataSourceSnapshot(orders: localOrders)
                DispatchQueue.main.sync { [weak self] in
                    guard let self else {
                        return
                    }
                    for order in localOrders {
                        self.items[order.orderID] = order
                    }
                    if localOrders.count == localPageCount {
                        self.resetLoadNextPageIndexPath(snapshot: snapshot)
                    }
                    UIView.performWithoutAnimation(self.tableView.removeEmptyIndicator)
                    self.dataSource.applySnapshotUsingReloadData(snapshot)
                    if didFinish {
                        Logger.general.info(category: "SwapOrderTable", message: "All remote orders loaded")
                    } else {
                        self.reloadRemoteOrders(offset: newestOrder.createdAt)
                    }
                }
            case .failure(let error):
                Logger.general.info(category: "SwapOrderTable", message: "\(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.reloadRemoteOrders(offset: offset)
                }
            }
        }
    }
    
}

fileprivate extension SwapOrderTableViewController.DataSourceSnapshot {
    
    init(orders: [SwapOrderItem]) {
        self.init()
        var sectionIdentifiers: Set<String> = []
        for order in orders {
            guard let createdAtDate = order.createdAtDate else {
                continue
            }
            let date = DateFormatter.dateSimple.string(from: createdAtDate)
            if !sectionIdentifiers.contains(date) {
                appendSections([date])
                sectionIdentifiers.insert(date)
            }
            appendItems([order.orderID], toSection: date)
        }
    }
    
}
