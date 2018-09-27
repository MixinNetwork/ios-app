import UIKit

class PeerTransactionsViewController: UITableViewController {
    
    private var opponentId = ""
    private var snapshots = [SnapshotItem]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let nib = UINib(nibName: "SnapshotCell", bundle: .main)
        tableView.register(nib, forCellReuseIdentifier: SnapshotCell.cellIdentifier)
        tableView.tableFooterView = UIView()
        reload()
        NotificationCenter.default.addObserver(self, selector: #selector(snapshotsDidChange(_:)), name: .SnapshotDidChange, object: nil)
        ConcurrentJobQueue.shared.addJob(job: RefreshSnapshotsJob(key: .opponentId(opponentId)))
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return snapshots.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SnapshotCell.cellIdentifier, for: indexPath) as! SnapshotCell
        cell.render(snapshot: snapshots[indexPath.row])
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return SnapshotCell.cellHeight
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let snapshot = snapshots[indexPath.row]
        if let asset = AssetDAO.shared.getAsset(assetId: snapshot.assetId) {
            let vc = TransactionViewController.instance(asset: asset, snapshot: snapshot)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @objc func snapshotsDidChange(_ notification: Notification) {
        reload()
    }
    
    class func instance(opponentId: String) -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "peer_transaction") as! PeerTransactionsViewController
        vc.opponentId = opponentId
        let container = ContainerViewController.instance(viewController: vc, title: Localized.PROFILE_TRANSACTIONS)
        container.automaticallyAdjustsScrollViewInsets = false
        return container
    }
    
    private func reload() {
        let id = self.opponentId
        DispatchQueue.global().async { [weak self] in
            let snapshots = SnapshotDAO.shared.getSnapshots(opponentId: id)
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.snapshots = snapshots
                UIView.performWithoutAnimation {
                    weakSelf.tableView.reloadData()
                }
            }
        }
    }
    
}
