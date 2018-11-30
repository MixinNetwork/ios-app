import UIKit

class AllTransactionsViewController: UITableViewController {
    
    private enum ReuseId {
        static let cell = "cell"
        static let header = "header"
    }
    
    private let dataSource = SnapshotDataSource(category: .all)
    private let loadNextPageThreshold = 20
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "SnapshotCell", bundle: .main),
                           forCellReuseIdentifier: ReuseId.cell)
        tableView.register(AssetHeaderView.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.header)
        dataSource.tableView = tableView
        dataSource.reloadFromLocal()
        dataSource.reloadFromRemote()
    }
    
    class func instance() -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "snapshot")
        let container = ContainerViewController.instance(viewController: vc, title: Localized.WALLET_ALL_TRANSACTIONS_TITLE)
        container.automaticallyAdjustsScrollViewInsets = false
        return container
    }
    
}

extension AllTransactionsViewController: ContainerViewControllerDelegate {
    
    var prefersNavigationBarSeparatorLineHidden: Bool {
        return true
    }
    
}

extension AllTransactionsViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource.titles.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.snapshots[section].count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ReuseId.cell, for: indexPath) as! SnapshotCell
        let snapshot = dataSource.snapshots[indexPath.section][indexPath.row]
        cell.render(snapshot: snapshot)
        cell.renderDecorationViews(indexPath: indexPath, models: dataSource.snapshots)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.header) as! AssetHeaderView
        view.label.text = dataSource.titles[section]
        return view
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let distance = dataSource.distanceToLastItem(of: indexPath), distance <= loadNextPageThreshold else {
            return
        }
        dataSource.loadMoreIfPossible()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let snapshot = dataSource.snapshots[indexPath.section][indexPath.row]
        DispatchQueue.global().async { [weak self] in
            guard let asset = AssetDAO.shared.getAsset(assetId: snapshot.assetId) else {
                return
            }
            DispatchQueue.main.async {
                self?.navigationController?.pushViewController(TransactionViewController.instance(asset: asset, snapshot: snapshot), animated: true)
            }
        }
    }
    
}
