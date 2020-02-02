import UIKit
import MixinServices

class AssetViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableHeaderView: AssetTableHeaderView!
    
    private enum ReuseId {
        static let header = "header"
    }
    
    private let loadMoreThreshold = 20
    
    private var asset: AssetItem!
    private var snapshotDataSource: SnapshotDataSource!
    
    private lazy var noTransactionFooterView = Bundle.main.loadNibNamed("NoTransactionFooterView", owner: self, options: nil)?.first as! UIView
    private lazy var filterController = AssetFilterViewController.instance(showFilters: true)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layoutIfNeeded()
        updateTableViewContentInset()
        updateTableHeaderFooterView()
        tableHeaderView.render(asset: asset)
        tableHeaderView.sizeToFit()
        tableView.register(R.nib.snapshotCell)
        tableView.register(AssetHeaderView.self, forHeaderFooterViewReuseIdentifier: ReuseId.header)
        tableView.dataSource = self
        tableView.delegate = self
        reloadAsset()
        snapshotDataSource.onReload = { [weak self] in
            guard let weakSelf = self else {
                return
            }
            weakSelf.tableView.reloadData()
            weakSelf.updateTableHeaderFooterView()
        }
        snapshotDataSource.reloadFromLocal()
        NotificationCenter.default.addObserver(self, selector: #selector(assetsDidChange(_:)), name: .AssetsDidChange, object: nil)
        ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob(assetId: asset.assetId))
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTableViewContentInset()
    }
    
    @objc func assetsDidChange(_ notification: Notification) {
        guard let assetId = notification.object as? String, assetId == asset.assetId else {
            return
        }
        reloadAsset()
    }
    
    @IBAction func presentFilterWindow(_ sender: Any) {
        filterController.delegate = self
        present(filterController, animated: true, completion: nil)
    }

    
    @IBAction func infoAction(_ sender: Any) {
        AssetInfoWindow.instance().presentWindow(asset: asset)
    }
    
    @IBAction func transfer(_ sender: Any) {
        guard let asset = self.asset else {
            return
        }
        let alc = UIAlertController(title: Localized.ACTION_SEND_TO, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.CHAT_MENU_CONTACT, style: .default, handler: { [weak self] (_) in
            let vc = TransferReceiverViewController.instance(asset: asset)
            self?.navigationController?.pushViewController(vc, animated: true)
        }))
        alc.addAction(UIAlertAction(title: Localized.WALLET_ADDRESS, style: .default, handler: { [weak self](_) in
            let vc = AddressViewController.instance(asset: asset)
            self?.navigationController?.pushViewController(vc, animated: true)
        }))
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        self.present(alc, animated: true, completion: nil)
    }
    
    @IBAction func deposit(_ sender: Any) {
        guard !tableHeaderView.depositButton.isBusy else {
            return
        }
        let vc = DepositViewController.instance(asset: asset)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    class func instance(asset: AssetItem) -> UIViewController {
        let vc = R.storyboard.wallet.asset()!
        vc.asset = asset
        vc.snapshotDataSource = SnapshotDataSource(category: .asset(id: asset.assetId))
        let container = ContainerViewController.instance(viewController: vc, title: asset.name)
        return container
    }
    
}

extension AssetViewController: ContainerViewControllerDelegate {
    
    var prefersNavigationBarSeparatorLineHidden: Bool {
        return true
    }
    
    func barRightButtonTappedAction() {
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let asset = self.asset!
        let toggleAssetHiddenTitle = AppGroupUserDefaults.Wallet.hiddenAssetIds[asset.assetId] == nil ? Localized.WALLET_MENU_HIDE_ASSET : Localized.WALLET_MENU_SHOW_ASSET
        alc.addAction(UIAlertAction(title: toggleAssetHiddenTitle, style: .default, handler: { [weak self](_) in
            guard let weakSelf = self else {
                return
            }
            if AppGroupUserDefaults.Wallet.hiddenAssetIds[asset.assetId] ?? false {
                AppGroupUserDefaults.Wallet.hiddenAssetIds.removeValue(forKey: asset.assetId)
            } else {
                AppGroupUserDefaults.Wallet.hiddenAssetIds[asset.assetId] = true
            }
            NotificationCenter.default.postOnMain(name: .AssetVisibleDidChange)
            weakSelf.navigationController?.popViewController(animated: true)
        }))
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        self.present(alc, animated: true, completion: nil)
    }
    
    func imageBarRightButton() -> UIImage? {
        return R.image.ic_title_more()
    }
    
}

extension AssetViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return snapshotDataSource.titles.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return snapshotDataSource.snapshots[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.snapshot, for: indexPath)!
        cell.render(snapshot: snapshotDataSource.snapshots[indexPath.section][indexPath.row], asset: asset)
        cell.delegate = self
        return cell
    }
    
}

extension AssetViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let snapshot = snapshotDataSource.snapshots[indexPath.section][indexPath.row]
        if snapshot.type != SnapshotType.pendingDeposit.rawValue {
            let vc = TransactionViewController.instance(asset: asset, snapshot: snapshot)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.header) as! AssetHeaderView
        header.label.text = snapshotDataSource.titles[section]
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let title = snapshotDataSource.titles[section]
        return title.isEmpty ? .leastNormalMagnitude : 44
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let distance = snapshotDataSource.distanceToLastItem(of: indexPath) else {
            return
        }
        if distance < loadMoreThreshold {
            snapshotDataSource.loadMoreIfPossible()
        }
    }
    
}

extension AssetViewController: AssetFilterViewControllerDelegate {
    
    func assetFilterViewController(_ controller: AssetFilterViewController, didApplySort sort: Snapshot.Sort, filter: Snapshot.Filter) {
        tableView.setContentOffset(.zero, animated: false)
        tableView.layoutIfNeeded()
        snapshotDataSource.setSort(sort, filter: filter)
        updateTableHeaderFooterView()
    }
    
}

extension AssetViewController: SnapshotCellDelegate {
    
    func walletSnapshotCellDidSelectIcon(_ cell: SnapshotCell) {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }
        let snapshot = snapshotDataSource.snapshots[indexPath.section][indexPath.row]
        guard snapshot.type == SnapshotType.transfer.rawValue, let userId = snapshot.opponentUserId else {
            return
        }
        DispatchQueue.global().async {
            guard let user = UserDAO.shared.getUser(userId: userId), user.isCreatedByMessenger else {
                return
            }
            DispatchQueue.main.async { [weak self] in
                let vc = UserProfileViewController(user: user)
                self?.present(vc, animated: true, completion: nil)
            }
        }
    }
    
}

extension AssetViewController {
    
    private func updateTableViewContentInset() {
        if view.safeAreaInsets.bottom < 1 {
            tableView.contentInset.bottom = 10
        } else {
            tableView.contentInset.bottom = 0
        }
    }
    
    private func reloadAsset() {
        let assetId = asset.assetId
        DispatchQueue.global().async { [weak self] in
            guard let asset = AssetDAO.shared.getAsset(assetId: assetId) else {
                return
            }
            self?.asset = asset
            DispatchQueue.main.sync {
                guard let weakSelf = self else {
                    return
                }
                UIView.performWithoutAnimation {
                    weakSelf.tableHeaderView.render(asset: asset)
                    weakSelf.tableHeaderView.sizeToFit()
                    weakSelf.updateTableHeaderFooterView()
                }
            }
        }
    }
    
    private func updateTableHeaderFooterView() {
        if snapshotDataSource.snapshots.isEmpty {
            tableHeaderView.transactionsHeaderView.isHidden = false
            noTransactionFooterView.frame.size.height = tableView.frame.height
                - tableView.contentSize.height
                - tableView.adjustedContentInset.vertical
            tableView.tableFooterView = noTransactionFooterView
        } else {
            tableHeaderView.transactionsHeaderView.isHidden = false
            tableView.tableFooterView = nil
        }
    }
    
}
