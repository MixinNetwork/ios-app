import UIKit

class SnapshotViewController: UITableViewController {

    private let pageLimit = 100

    private var snapshots = [SnapshotItem]()
    private var pageOffset = 0
    private var pageEnded = false
    private var fetching = false

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "SnapshotCell", bundle: .main),
                           forCellReuseIdentifier: SnapshotCell.cellIdentifier)
        fetchRemoteSnapshots()
        fetchSnapshots()
    }

    private func fetchSnapshots(nextPage: Bool = false) {
        guard !fetching else {
            return
        }
        fetching = true
        let pageLimit = self.pageLimit
        let pageOffset = nextPage ? self.pageOffset : 0
        DispatchQueue.global().async { [weak self] in
            let snapshots = SnapshotDAO.shared.snapshots(offset: pageOffset, limit: pageLimit)
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.pageEnded = snapshots.count < pageLimit
                weakSelf.pageOffset += snapshots.count
                if nextPage {
                    weakSelf.snapshots += snapshots
                } else {
                    weakSelf.snapshots = snapshots
                }
                weakSelf.tableView.reloadData()
                weakSelf.fetching = false
            }
        }
    }

    private func fetchRemoteSnapshots() {
        AssetAPI.shared.snapshots { (result) in
            switch result {
            case let .success(snapshots):
                SnapshotDAO.shared.insertOrUpdateSnapshots(snapshots: snapshots)
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

extension SnapshotViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return snapshots.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SnapshotCell.cellIdentifier, for: indexPath) as! SnapshotCell
        cell.render(snapshot: snapshots[indexPath.row])
        return cell
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard !pageEnded, !fetching, snapshots.count > 0, indexPath.row > snapshots.count - 20 else {
            return
        }
        fetchSnapshots(nextPage: true)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let snapshot = snapshots[indexPath.row]
        DispatchQueue.global().async { [weak self] in
            guard let asset = AssetDAO.shared.getAsset(assetId: snapshot.assetId) else {
                return
            }
            DispatchQueue.main.async {
                self?.navigationController?.pushViewController(TransactionViewController.instance(asset: asset, snapshot: snapshot), animated: true)
            }
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return SnapshotCell.cellHeight
    }
}
