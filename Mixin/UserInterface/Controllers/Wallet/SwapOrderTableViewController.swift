import UIKit
import MixinServices

final class SwapOrderTableViewController: UITableViewController {
    
    private let localPageCount = 50
    private let remotePageCount = 100
    
    private var sections: [Section] = []
    private var loadNextPageIndexPath: IndexPath?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = R.string.localizable.order()
        view.backgroundColor = R.color.background()
        tableView.backgroundColor = R.color.background()
        tableView.register(R.nib.swapOrderCell)
        tableView.rowHeight = 90
        tableView.separatorStyle = .none
        updateTableViewContentInsetBottom()
        DispatchQueue.global().async { [limit=localPageCount] in
            let orders = SwapOrderDAO.shared.orders(limit: limit)
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                if let newestOrder = orders.first {
                    self.sections = [Section(source: .local, orders: orders)]
                    if orders.count == limit {
                        self.resetLoadNextPageIndexPath()
                    }
                    self.tableView.reloadData()
                    self.reloadRemoteOrders(offset: newestOrder.createdAt)
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
        sections[section].orders.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.swap_order, for: indexPath)!
        let order = sections[indexPath.section].orders[indexPath.row]
        cell.load(order: order)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath == loadNextPageIndexPath, let oldestOrder = sections.last?.orders.last {
            loadNextPageIndexPath = nil
            DispatchQueue.global().async { [limit=localPageCount] in
                let orders = SwapOrderDAO.shared.orders(before: oldestOrder.createdAt, limit: limit)
                guard !orders.isEmpty else {
                    return
                }
                DispatchQueue.main.sync { [weak self] in
                    guard let self, self.sections.last?.orders.last == oldestOrder else {
                        return
                    }
                    let newSectionIndex = self.sections.count
                    self.sections.append(Section(source: .local, orders: orders))
                    if orders.count == limit {
                        self.resetLoadNextPageIndexPath()
                    }
                    self.tableView.insertSections(IndexSet(integer: newSectionIndex), with: .none)
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let order = sections[indexPath.section].orders[indexPath.row]
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
            row: max(0, lastSection.orders.count - 3),
            section: sections.count - 1
        )
    }
    
}

extension SwapOrderTableViewController {
    
    struct Section {
        
        enum Source {
            case local
            case remote
        }
        
        let source: Source
        let orders: [SwapOrderItem]
        
    }
    
    private func reloadRemoteOrders(offset: String?) {
        let limit = remotePageCount
        RouteAPI.mixinSwapOrders(
            offset: offset,
            limit: limit,
            queue: .global()
        ) { [weak self] result in
            switch result {
            case .success(let orders):
                guard let oldestOrder = orders.first, let newestOrder = orders.last else {
                    // Empty results, the newest order is loaded
                    return
                }
                let didFinish = SwapOrderDAO.shared.orderExists(orderID: oldestOrder.orderID)
                || orders.count < limit
                let newOrders = SwapOrderDAO.shared.saveAndFetch(orders: orders)
                DispatchQueue.main.sync {
                    guard let self else {
                        return
                    }
                    if offset == nil {
                        self.sections = [Section(source: .remote, orders: newOrders)]
                        self.resetLoadNextPageIndexPath()
                        self.tableView.reloadData()
                    } else {
                        self.tableView.performBatchUpdates {
                            var localSections = IndexSet()
                            self.sections = self.sections.enumerated().compactMap { (index, section) in
                                switch section.source {
                                case .local:
                                    localSections.insert(index)
                                    return nil
                                case .remote:
                                    return section
                                }
                            }
                            let newSection = Section(source: .remote, orders: newOrders)
                            self.sections.insert(newSection, at: 0)
                            self.tableView.deleteSections(localSections, with: .none)
                            self.tableView.insertSections(IndexSet(integer: 0), with: .none)
                        }
                    }
                    if !didFinish {
                        self.reloadRemoteOrders(offset: newestOrder.createdAt)
                    }
                }
            case .failure(let error):
                Logger.general.debug(category: "MixinSwapOrderTable", message: "\(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.reloadRemoteOrders(offset: offset)
                }
            }
        }
    }
    
}
