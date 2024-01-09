import UIKit
import MixinServices

class AllTransactionsViewController: UITableViewController {
    
    private enum ReuseId {
        static let header = "header"
    }
    
    var dataSource: SnapshotDataSource!
    
    var showFilters: Bool {
        return true
    }
    
    private let loadNextPageThreshold = 20
    
    private lazy var filterController = AssetFilterViewController.instance()
    
    class func instance() -> UIViewController {
        let vc = R.storyboard.wallet.snapshot()!
        vc.dataSource = SnapshotDataSource(category: .all)
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.all_transactions())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(R.nib.snapshotCell)
        tableView.register(AssetHeaderView.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.header)
        dataSource.onReload = { [weak self] in
            guard let weakSelf = self else {
                return
            }
            weakSelf.tableView.reloadData()
            weakSelf.tableView.checkEmpty(dataCount: weakSelf.dataSource.snapshots.count,
                                          text: R.string.localizable.no_transactions(),
                                          photo: R.image.emptyIndicator.ic_data()!)
        }
        dataSource.reloadFromLocal()
        dataSource.reloadFromRemote()
        updateTableViewContentInset()
        SafeAPI.allDeposits(queue: .global()) { result in
            guard case .success(let deposits) = result else {
                return
            }
            let entries = DepositEntryDAO.shared.compactEntries()
            let myDeposits = deposits.filter { deposit in
                // `SafeAPI.allDeposits` returns all deposits, whether it's mine or other's
                // Filter with my entries to get my deposits
                entries.contains(where: { (entry) in
                    let isDestinationMatch = entry.destination == deposit.destination
                    let isTagMatch: Bool
                    if entry.tag.isNilOrEmpty && deposit.tag.isNilOrEmpty {
                        isTagMatch = true
                    } else if entry.tag == deposit.tag {
                        isTagMatch = true
                    } else {
                        isTagMatch = false
                    }
                    return isDestinationMatch && isTagMatch
                })
            }
            SafeSnapshotDAO.shared.replaceAllPendingSnapshots(with: myDeposits)
        }
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTableViewContentInset()
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
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.snapshot, for: indexPath)!
        let snapshot = dataSource.snapshots[indexPath.section][indexPath.row]
        cell.render(snapshot: snapshot)
        cell.delegate = self
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
            guard let asset = TokenDAO.shared.tokenItem(with: snapshot.assetID) else {
                return
            }
            DispatchQueue.main.async {
                let viewController = SnapshotViewController.instance(token: asset, snapshot: snapshot)
                self?.navigationController?.pushViewController(viewController, animated: true)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let title = dataSource.titles[section]
        return title.isEmpty ? .leastNormalMagnitude : 44
    }
    
    private func updateTableViewContentInset() {
        if view.safeAreaInsets.bottom < 1 {
            tableView.contentInset.bottom = 10
        } else {
            tableView.contentInset.bottom = 0
        }
    }
    
}

extension AllTransactionsViewController: ContainerViewControllerDelegate {
    
    var prefersNavigationBarSeparatorLineHidden: Bool {
        return true
    }
    
    func barRightButtonTappedAction() {
        filterController.delegate = self
        present(filterController, animated: true, completion: nil)
    }
    
    func imageBarRightButton() -> UIImage? {
        R.image.wallet.ic_filter_large()
    }
    
}

extension AllTransactionsViewController: AssetFilterViewControllerDelegate {
    
    func assetFilterViewController(_ controller: AssetFilterViewController, didApplySort sort: Snapshot.Sort) {
        tableView.setContentOffset(.zero, animated: false)
        dataSource.setSort(sort)
    }
    
}

extension AllTransactionsViewController: SnapshotCellDelegate {
    
    func walletSnapshotCellDidSelectIcon(_ cell: SnapshotCell) {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }
        let snapshot = dataSource.snapshots[indexPath.section][indexPath.row]
        guard let userId = snapshot.opponentUserID else {
            return
        }
        DispatchQueue.global().async {
            guard let user = UserDAO.shared.getUser(userId: userId) else {
                return
            }
            DispatchQueue.main.async { [weak self] in
                let vc = UserProfileViewController(user: user)
                self?.present(vc, animated: true, completion: nil)
            }
        }
    }
    
}
