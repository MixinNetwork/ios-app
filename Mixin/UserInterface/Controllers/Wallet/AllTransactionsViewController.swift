import UIKit

class AllTransactionsViewController: UITableViewController {
    
    private enum ReuseId {
        static let cell = "cell"
        static let header = "header"
    }
    private let pageLimit = 100
    
    private var titles = [String]()
    private var snapshots = [[SnapshotItem]]()
    
    private var didLoadLastSnapshot = false
    private var isLoading = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "SnapshotCell", bundle: .main),
                           forCellReuseIdentifier: ReuseId.cell)
        tableView.register(AssetHeaderView.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.header)
        fetchRemoteSnapshots()
        fetchSnapshots()
    }
    
    private func fetchSnapshots() {
        guard !isLoading else {
            return
        }
        isLoading = true
        let pageLimit = self.pageLimit
        let location = snapshots.last?.last
        var newTitles = self.titles
        var newSnapshots = self.snapshots
        DispatchQueue.global().async { [weak self] in
            var lastTitle = newTitles.last
            let snapshots = SnapshotDAO.shared.getSnapshots(below: location, sort: .createdAt, limit: pageLimit)
            for snapshot in snapshots {
                let title = DateFormatter.dateSimple.string(from: snapshot.createdAt.toUTCDate())
                if title == lastTitle {
                    newSnapshots[newSnapshots.count - 1].append(snapshot)
                } else {
                    lastTitle = title
                    newTitles.append(title)
                    newSnapshots.append([snapshot])
                }
            }
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.didLoadLastSnapshot = snapshots.count < pageLimit
                weakSelf.titles = newTitles
                weakSelf.snapshots = newSnapshots
                weakSelf.tableView.reloadData()
                weakSelf.isLoading = false
            }
        }
    }
    
    private func fetchRemoteSnapshots() {
        AssetAPI.shared.snapshots { (result) in
            switch result {
            case let .success(snapshots):
                SnapshotDAO.shared.insertOrReplaceSnapshots(snapshots: snapshots)
            case .failure:
                break
            }
        }
    }
    
    class func instance() -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "snapshot")
        return ContainerViewController.instance(viewController: vc, title: Localized.WALLET_ALL_TRANSACTIONS_TITLE)
    }
    
}

extension AllTransactionsViewController: ContainerViewControllerDelegate {
    
    var prefersNavigationBarSeparatorLineHidden: Bool {
        return true
    }
    
}

extension AllTransactionsViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return titles.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return snapshots[section].count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ReuseId.cell, for: indexPath) as! SnapshotCell
        let snapshot = snapshots[indexPath.section][indexPath.row]
        cell.render(snapshot: snapshot)
        cell.renderDecorationViews(indexPath: indexPath, models: snapshots)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.header) as! AssetHeaderView
        view.label.text = titles[section]
        return view
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard !didLoadLastSnapshot, !isLoading, snapshots.count > 0, indexPath.section == titles.count - 1 else {
            return
        }
        fetchSnapshots()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let snapshot = snapshots[indexPath.section][indexPath.row]
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
