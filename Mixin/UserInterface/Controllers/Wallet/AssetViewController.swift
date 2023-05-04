import UIKit
import web3 // Remove this after TIP Wallet transfer is removed
import MixinServices

class AssetViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableHeaderView: AssetTableHeaderView!
    
    private enum ReuseId {
        static let header = "header"
    }
    
    private let loadMoreThreshold = 20
    
    private(set) var asset: AssetItem!
    private var snapshotDataSource: SnapshotDataSource!
    private var performSendOnAppear = false
        
    private lazy var noTransactionFooterView = Bundle.main.loadNibNamed("NoTransactionFooterView", owner: self, options: nil)?.first as! UIView
    private lazy var filterController = AssetFilterViewController.instance(showFilters: true)
    
    private weak var job: RefreshAssetsJob?
    
    deinit {
        job?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layoutIfNeeded()
        updateTableViewContentInset()
        updateTableHeaderFooterView()
        tableHeaderView.render(asset: asset)
        tableHeaderView.sizeToFit()
        tableHeaderView.transferActionView.delegate = self
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
        NotificationCenter.default.addObserver(self, selector: #selector(assetsDidChange(_:)), name: AssetDAO.assetsDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(chainsDidChange(_:)), name: ChainDAO.chainsDidChangeNotification, object: nil)
        let job = RefreshAssetsJob(request: .asset(id: asset.assetId, untilDepositEntriesNotEmpty: false))
        self.job = job
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if performSendOnAppear {
            performSendOnAppear = false
            DispatchQueue.main.async(execute: send)
        }
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTableViewContentInset()
    }
    
    @objc func assetsDidChange(_ notification: Notification) {
        guard let id = notification.userInfo?[AssetDAO.UserInfoKey.assetId] as? String else {
            return
        }
        guard id == asset.assetId else {
            return
        }
        reloadAsset()
    }
    
    @objc private func chainsDidChange(_ notification: Notification) {
        guard let id = notification.userInfo?[ChainDAO.UserInfoKey.chainId] as? String else {
            return
        }
        guard id == asset.chainId else {
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
    
    class func instance(asset: AssetItem, performSendOnAppear: Bool = false) -> UIViewController {
        let vc = R.storyboard.wallet.asset()!
        vc.asset = asset
        vc.performSendOnAppear = performSendOnAppear
        vc.snapshotDataSource = SnapshotDataSource(category: .asset(id: asset.assetId))
        let container = ContainerViewController.instance(viewController: vc, title: asset.name)
        return container
    }
    
}

extension AssetViewController: TransferActionViewDelegate {
    
    func transferActionView(_ view: TransferActionView, didSelect action: TransferActionView.Action) {
        switch action {
        case .send:
            send()
        case .receive:
            let controller: UIViewController
            if asset.isDepositSupported {
                controller = DepositViewController.instance(asset: asset)
            } else {
                controller = DepositNotSupportedViewController.instance(asset: asset)
            }
            navigationController?.pushViewController(controller, animated: true)
        }
    }
    
}

extension AssetViewController: ContainerViewControllerDelegate {
    
    var prefersNavigationBarSeparatorLineHidden: Bool {
        return true
    }
    
    func barRightButtonTappedAction() {
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let asset = self.asset!
        let toggleAssetHiddenTitle = AppGroupUserDefaults.Wallet.hiddenAssetIds[asset.assetId] == nil ? R.string.localizable.hide_asset() : R.string.localizable.show_asset()
        alc.addAction(UIAlertAction(title: toggleAssetHiddenTitle, style: .default, handler: { [weak self](_) in
            guard let weakSelf = self else {
                return
            }
            if AppGroupUserDefaults.Wallet.hiddenAssetIds[asset.assetId] ?? false {
                AppGroupUserDefaults.Wallet.hiddenAssetIds.removeValue(forKey: asset.assetId)
            } else {
                AppGroupUserDefaults.Wallet.hiddenAssetIds[asset.assetId] = true
            }
            weakSelf.navigationController?.popViewController(animated: true)
        }))
        alc.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
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
        let vc = TransactionViewController.instance(asset: asset, snapshot: snapshot)
        navigationController?.pushViewController(vc, animated: true)
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

extension AssetViewController {
    
    private func send() {
        guard let asset = self.asset else {
            return
        }
        let alert = UIAlertController(title: R.string.localizable.send_to_title(), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: R.string.localizable.contact(), style: .default, handler: { [weak self] (_) in
            let vc = TransferReceiverViewController.instance(asset: asset)
            self?.navigationController?.pushViewController(vc, animated: true)
        }))
        alert.addAction(UIAlertAction(title: R.string.localizable.address(), style: .default, handler: { [weak self](_) in
            let vc = AddressViewController.instance(asset: asset)
            self?.navigationController?.pushViewController(vc, animated: true)
        }))
        
        let withdrawToTIPAllowedChainIds = [
            "43d61dcd-e413-450d-80b8-101d5e903357", // Ethereum
            "b7938396-3f94-4e0a-9179-d3440718156f", // Polygon
            "1949e683-6a08-49e2-b087-d6b72398588f", // Binance Smart Chain
        ]
        if withdrawToTIPAllowedChainIds.contains(asset.chainId) {
            alert.addAction(UIAlertAction(title: "TIP Wallet", style: .default, handler: { _ in
                self.sendToMyTIPWallet()
            }))
        }
        
        alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func sendToMyTIPWallet() {
        let reveal = RevealTIPWalletAddressViewController()
        reveal.onApprove = { [asset] priv in
            let storage = InPlaceKeyStorage(raw: priv)
            let account = try! EthereumAccount(keyStorage: storage)
            let address = account.address.toChecksumAddress()
            let transfer = TransferOutViewController.instance(asset: asset, type: .tipWallet(address))
            self.navigationController?.pushViewController(transfer, animated: true)
        }
        let authentication = AuthenticationViewController(intentViewController: reveal)
        present(authentication, animated: true)
    }
    
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
            DispatchQueue.main.sync {
                guard let self = self else {
                    return
                }
                self.asset = asset
                UIView.performWithoutAnimation {
                    self.tableHeaderView.render(asset: asset)
                    self.tableHeaderView.sizeToFit()
                    self.updateTableHeaderFooterView()
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
