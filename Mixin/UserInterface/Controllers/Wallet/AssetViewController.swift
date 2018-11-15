import UIKit

class AssetViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    private enum ReuseId {
        static let cell  = "snapshot"
        static let header = "header"
    }
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.asset-load")
    private let tableHeaderView = AssetTableHeaderView()
    private let noTransactionFooterView = Bundle.main.loadNibNamed("NoTransactionFooterView", owner: self, options: nil)?.first as! UIView
    
    private var asset: AssetItem!
    private var snapshots = [SnapshotItem]() {
        didSet {
            updateFilteredSnapshots()
        }
    }
    private var filteredSnapshots = [[SnapshotItem]]()
    private var headerTitles = [String]()
    private var didLoadRemoteSnapshots = false
    private var showTitleHeaderView: Bool {
        return !headerTitles.isEmpty && filterWindow.sort == .time
    }
    
    private lazy var filterWindow: AssetFilterWindow = {
        let window = AssetFilterWindow.instance()
        window.delegate = self
        return window
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateTableViewContentInset()
        tableHeaderView.sizeToFit()
        tableHeaderView.filterButton.addTarget(filterWindow, action: #selector(AssetFilterWindow.presentPopupControllerAnimated), for: .touchUpInside)
        tableHeaderView.titleView.withdrawalButton.addTarget(self, action: #selector(withdraw(_:)), for: .touchUpInside)
        tableHeaderView.titleView.depositButton.addTarget(self, action: #selector(deposit(_:)), for: .touchUpInside)
        tableView.tableHeaderView = tableHeaderView
        tableView.register(AssetHeaderView.self, forHeaderFooterViewReuseIdentifier: ReuseId.header)
        tableView.dataSource = self
        tableView.delegate = self
        reloadAsset()
        reloadSnapshots()
        NotificationCenter.default.addObserver(self, selector: #selector(assetsDidChange(_:)), name: .AssetsDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(snapshotsDidChange(_:)), name: .SnapshotDidChange, object: nil)
        ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob(assetId: asset.assetId))
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @available(iOS 11.0, *)
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
    
    @objc func snapshotsDidChange(_ notification: Notification) {
        didLoadRemoteSnapshots = true
        reloadSnapshots()
    }
    
    @objc func withdraw(_ sender: Any) {
        let vc = WithdrawalViewController.instance(asset: asset)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc func deposit(_ sender: Any) {
        guard !tableHeaderView.titleView.depositButton.isBusy else {
            return
        }
        let vc = DepositViewController.instance(asset: asset)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    class func instance(asset: AssetItem) -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "asset") as! AssetViewController
        vc.asset = asset
        let container = ContainerViewController.instance(viewController: vc, title: asset.name)
        container.automaticallyAdjustsScrollViewInsets = false
        return container
    }
    
}

extension AssetViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.WALLET_MENU_WITHDRAW, style: .default, handler: { [weak self] (_) in
            self?.withdraw(alc)
        }))
        let toggleAssetHiddenTitle = WalletUserDefault.shared.hiddenAssets[asset.assetId] == nil ? Localized.WALLET_MENU_HIDE_ASSET : Localized.WALLET_MENU_SHOW_ASSET
        alc.addAction(UIAlertAction(title: toggleAssetHiddenTitle, style: .default, handler: { [weak self](_) in
            guard let weakSelf = self, let asset = weakSelf.asset else {
                return
            }
            if WalletUserDefault.shared.hiddenAssets[asset.assetId] == nil {
                WalletUserDefault.shared.hiddenAssets[asset.assetId] = asset.assetId
            } else {
                WalletUserDefault.shared.hiddenAssets.removeValue(forKey: asset.assetId)
            }
            NotificationCenter.default.postOnMain(name: .AssetVisibleDidChange)
            weakSelf.navigationController?.popViewController(animated: true)
        }))
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        self.present(alc, animated: true, completion: nil)
    }
    
    func imageBarRightButton() -> UIImage? {
        return #imageLiteral(resourceName: "ic_titlebar_more")
    }
    
}

extension AssetViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return filteredSnapshots.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredSnapshots[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ReuseId.cell, for: indexPath) as! WalletSnapshotCell
        cell.render(snapshot: filteredSnapshots[indexPath.section][indexPath.row], asset: asset)
        let lastSection = filteredSnapshots.count - 1
        let lastIndexPath = IndexPath(row: filteredSnapshots[lastSection].count - 1, section: lastSection)
        if indexPath == lastIndexPath {
            cell.bottomShadowImageView.isHidden = false
            cell.selectionView.roundingCorners = [.bottomLeft, .bottomRight]
        } else {
            cell.bottomShadowImageView.isHidden = true
            cell.selectionView.roundingCorners = []
        }
        return cell
    }
    
}

extension AssetViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let snapshot = filteredSnapshots[indexPath.section][indexPath.row]
        if snapshot.type != SnapshotType.pendingDeposit.rawValue {
            let vc = TransactionViewController.instance(asset: asset, snapshot: snapshot)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard showTitleHeaderView else {
            return nil
        }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.header) as! AssetHeaderView
        header.label.text = headerTitles[section]
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return SnapshotCell.cellHeight
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return showTitleHeaderView ? 32 : .leastNormalMagnitude
    }
    
}

extension AssetViewController: AssetFilterWindowDelegate {
    
    func assetFilterWindow(_ window: AssetFilterWindow, didApplySort: AssetFilterWindow.Sort, filter: AssetFilterWindow.Filter) {
        tableView.setContentOffset(.zero, animated: false)
        tableView.layoutIfNeeded()
        updateFilteredSnapshots()
        tableView.reloadData()
        updateTableFooterView()
    }
    
}

extension AssetViewController {
    
    private func updateTableViewContentInset() {
        if view.compatibleSafeAreaInsets.bottom < 1 {
            tableView.contentInset.bottom = 10
        } else {
            tableView.contentInset.bottom = 0
        }
    }
    
    private func reloadAsset() {
        let assetId = asset.assetId
        queue.async { [weak self] in
            guard let asset = AssetDAO.shared.getAsset(assetId: assetId) else {
                return
            }
            self?.asset = asset
            DispatchQueue.main.sync {
                guard let weakSelf = self else {
                    return
                }
                UIView.performWithoutAnimation {
                    weakSelf.tableHeaderView.titleView.render(asset: asset)
                    weakSelf.updateTableFooterView()
                }
            }
        }
    }
    
    private func reloadSnapshots() {
        let assetId = asset.assetId
        queue.async { [weak self] in
            let snapshots = SnapshotDAO.shared.getSnapshots(assetId: assetId)
            let inexistedUserIds = snapshots
                .filter({ $0.opponentUserFullName == nil })
                .compactMap({ $0.opponentId })
            if !inexistedUserIds.isEmpty {
                ConcurrentJobQueue.shared.addJob(job: RefreshUserJob(userIds: inexistedUserIds))
            }
            DispatchQueue.main.sync { [weak self] in
                guard let weakSelf = self else {
                    return
                }
                weakSelf.snapshots = snapshots
                UIView.performWithoutAnimation {
                    weakSelf.tableView.reloadData()
                    weakSelf.updateTableFooterView()
                }
            }
        }
    }
    
    private func updateFilteredSnapshots() {
        let visibleSnapshotTypes = filterWindow
            .filter
            .snapshotTypes
            .map({ $0.rawValue })
        let sortedSnapshots = self.snapshots
            .filter({ visibleSnapshotTypes.contains($0.type) })
            .sorted(by: filterWindow.sort == .time ? timeSorter : amountSorter)
        switch filterWindow.sort {
        case .time:
            var keys = [String]()
            var dict = [String: [SnapshotItem]]()
            for snapshot in sortedSnapshots {
                let date = DateFormatter.dateSimple.string(from: snapshot.createdAt.toUTCDate())
                if dict[date] != nil {
                    dict[date]?.append(snapshot)
                } else {
                    keys.append(date)
                    dict[date] = [snapshot]
                }
            }
            var snapshots = [[SnapshotItem]]()
            for key in keys {
                snapshots.append(dict[key] ?? [])
            }
            self.headerTitles = keys
            self.filteredSnapshots = snapshots
        case .amount:
            headerTitles = []
            let snapshots = self.snapshots
                .filter({ visibleSnapshotTypes.contains($0.type) })
                .sorted(by: amountSorter)
            filteredSnapshots = [snapshots]
        }
    }
    
    private func timeSorter(_ one: SnapshotItem, _ another: SnapshotItem) -> Bool {
        return one.createdAt > another.createdAt
    }
    
    private func amountSorter(_ one: SnapshotItem, _ another: SnapshotItem) -> Bool {
        let oneValue = Double(one.amount) ?? 0
        let anotherValue = Double(another.amount) ?? 0
        if abs(oneValue) == abs(anotherValue), oneValue.sign != anotherValue.sign {
            return oneValue > 0
        } else {
            return abs(oneValue) > abs(anotherValue)
        }
    }
    
    private func updateTableFooterView() {
        if filteredSnapshots.isEmpty {
            if didLoadRemoteSnapshots {
                tableHeaderView.transactionsHeaderView.isHidden = false
                if #available(iOS 11.0, *) {
                    noTransactionFooterView.frame.size.height = tableView.frame.height
                        - tableView.contentSize.height
                        - tableView.adjustedContentInset.vertical
                } else {
                    noTransactionFooterView.frame.size.height = tableView.frame.height
                        - tableView.contentSize.height
                        - tableView.contentInset.vertical
                }
                tableView.tableFooterView = noTransactionFooterView
            } else {
                tableHeaderView.transactionsHeaderView.isHidden = true
                tableView.tableFooterView = nil
            }
        } else {
            tableHeaderView.transactionsHeaderView.isHidden = false
            tableView.tableFooterView = nil
        }
    }
    
}
