import UIKit
import MixinServices

final class SwapOrderTableViewController: UITableViewController {
    
    private let localPageCount = 50
    private let remotePageCount = 100
    
    private var sections: [[SwapOrderItem]] = []
    private var loadNextPageIndexPath: IndexPath?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = R.string.localizable.orders()
        view.backgroundColor = R.color.background()
        tableView.backgroundColor = R.color.background()
        tableView.register(R.nib.swapOrderCell)
        tableView.estimatedRowHeight = 85
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        updateTableViewContentInsetBottom()
        DispatchQueue.global().async { [limit=localPageCount] in
            let orders = SwapOrderDAO.shared.orders(limit: limit)
            let offset = SwapOrderDAO.shared.oldestPendingOrFailedOrderCreatedAt()
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                if let newestOrder = orders.first {
                    self.sections = [orders]
                    if orders.count == limit {
                        self.resetLoadNextPageIndexPath()
                    }
                    UIView.performWithoutAnimation(self.tableView.reloadData)
                    let offset = offset ?? newestOrder.createdAt
                    self.reloadRemoteOrders(offset: offset)
                } else {
                    self.reloadRemoteOrders(offset: nil)
                }
            }
        }
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTableViewContentInsetBottom()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.swap_order, for: indexPath)!
        let order = sections[indexPath.section][indexPath.row]
        cell.load(order: order)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath == loadNextPageIndexPath, let offset = sections.last?.last {
            loadNextPageIndexPath = nil
            Logger.general.info(category: "SwapOrderTable", message: "Loading local orders before \(offset.createdAt)")
            DispatchQueue.global().async { [limit=localPageCount] in
                let orders = SwapOrderDAO.shared.orders(before: offset.createdAt, limit: limit)
                guard let oldestOrder = orders.last, let newestOrder = orders.first else {
                    Logger.general.info(category: "SwapOrderTable", message: "All local orders loaded")
                    return
                }
                DispatchQueue.main.sync { [weak self] in
                    guard let self, self.sections.last?.last == offset else {
                        return
                    }
                    let newSectionIndex = self.sections.count
                    self.sections.append(orders)
                    Logger.general.info(category: "SwapOrderTable", message: "Appended \(orders.count) local orders at \(newSectionIndex), range: \(newestOrder.createdAt) ~ \(oldestOrder.createdAt)")
                    if orders.count == limit {
                        self.resetLoadNextPageIndexPath()
                    }
                    UIView.performWithoutAnimation {
                        self.tableView.insertSections(IndexSet(integer: newSectionIndex), with: .none)
                    }
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let order = sections[indexPath.section][indexPath.row]
        let details = SwapOrderViewController(order: order)
        navigationController?.pushViewController(details, animated: true)
    }
    
    private func updateTableViewContentInsetBottom() {
        if view.safeAreaInsets.bottom > 10 {
            tableView.contentInset.bottom = 0
        } else {
            tableView.contentInset.bottom = 10
        }
    }
    
    private func resetLoadNextPageIndexPath() {
        guard let lastSection = sections.last else {
            return
        }
        loadNextPageIndexPath = IndexPath(
            row: max(0, lastSection.count - 3),
            section: sections.count - 1
        )
    }
    
}

extension SwapOrderTableViewController {
    
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
                let localOrders = SwapOrderDAO.shared.orders(limit: localPageCount)
                DispatchQueue.main.sync {
                    guard let self else {
                        return
                    }
                    self.sections = [localOrders]
                    if localOrders.count == localPageCount {
                        self.resetLoadNextPageIndexPath()
                    }
                    UIView.performWithoutAnimation(self.tableView.reloadData)
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
