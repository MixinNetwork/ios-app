import UIKit

class AssetViewController: UITableViewController {

    private var asset: AssetItem!
    private var filteredSnapshots = [SnapshotItem]()
    private var snapshots = [SnapshotItem]() {
        didSet {
            updateFilteredSnapshots()
        }
    }
    
    private let headerReuseId = "header"
    
    private lazy var filterWindow: AssetFilterWindow = {
        let window = AssetFilterWindow.instance()
        window.delegate = self
        return window
    }()
    private lazy var noTransactionIndicator: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .lightGray
        label.text = Localized.WALLET_NO_TRANSACTION
        label.sizeToFit()
        label.frame.size.height += 40
        return label
    }()
    private lazy var emptyFooterView = UIView()
    
    @IBOutlet weak var iconImageView: AvatarImageView!
    @IBOutlet weak var blockchainImageView: CornerImageView!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var exchangeLabel: UILabel!
    @IBOutlet weak var depositButton: StateResponsiveButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "SnapshotCell", bundle: .main),
                           forCellReuseIdentifier: SnapshotCell.cellIdentifier)
        tableView.register(FilterableHeaderView.self,
                           forHeaderFooterViewReuseIdentifier: headerReuseId)
        reloadAssetSection()
        reloadData(showEmptyIndicatorIfEmpty: false)
        NotificationCenter.default.addObserver(self, selector: #selector(assetsDidChange(_:)), name: .AssetsDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(snapshotsDidChange(_:)), name: .SnapshotDidChange, object: nil)
        ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob(assetId: asset.assetId))
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func assetsDidChange(_ notification: Notification) {
        guard let assetId = notification.object as? String, assetId == asset.assetId else {
            return
        }
        reloadData(showEmptyIndicatorIfEmpty: false)
    }
    
    @objc func snapshotsDidChange(_ notification: Notification) {
        reloadData(showEmptyIndicatorIfEmpty: true)
    }
    
    @IBAction func depositAction(_ sender: Any) {
        guard !depositButton.isBusy else {
            return
        }
        navigationController?.pushViewController(DepositViewController.instance(asset: asset), animated: true)
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
            guard let weakSelf = self else {
                return
            }
            let vc = WithdrawalViewController.instance(asset: weakSelf.asset)
            weakSelf.navigationController?.pushViewController(vc, animated: true)
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

extension AssetViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 1 {
            return filteredSnapshots.count
        } else {
            return super.tableView(tableView, numberOfRowsInSection: section)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: SnapshotCell.cellIdentifier, for: indexPath) as! SnapshotCell
            cell.render(snapshot: filteredSnapshots[indexPath.row], asset: asset)
            return cell
        } else {
            return super.tableView(tableView, cellForRowAt: indexPath)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 1 {
            let snapshot = filteredSnapshots[indexPath.row]
            if snapshot.type != SnapshotType.pendingDeposit.rawValue {
                let vc = TransactionViewController.instance(asset: asset, snapshot: snapshot)
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
}
    
extension AssetViewController {
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section == 1 else {
            return nil
        }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseId) as! FilterableHeaderView
        header.filterAction = { [weak self] in
            self?.filterWindow.presentPopupControllerAnimated()
        }
        return header
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 1 {
            return SnapshotCell.cellHeight
        } else {
            return UITableView.automaticDimension
        }
    }
    
    override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
        if indexPath.section == 1 {
            return 0
        } else {
            return super.tableView(tableView, indentationLevelForRowAt: indexPath)
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? CGFloat.leastNormalMagnitude : 30
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 10
    }
    
}

extension AssetViewController: AssetFilterWindowDelegate {
    
    func assetFilterWindow(_ window: AssetFilterWindow, didApplySort: AssetFilterWindow.Sort, filter: AssetFilterWindow.Filter) {
        tableView.setContentOffset(.zero, animated: false)
        tableView.layoutIfNeeded()
        updateFilteredSnapshots()
        tableView.reloadData()
        tableView.tableFooterView = filteredSnapshots.isEmpty ? noTransactionIndicator : emptyFooterView
    }
    
}

extension AssetViewController {
    
    private func reloadData(showEmptyIndicatorIfEmpty: Bool) {
        let assetId = asset.assetId
        DispatchQueue.global().async { [weak self] in
            if let asset = AssetDAO.shared.getAsset(assetId: assetId) {
                self?.asset = asset
                DispatchQueue.main.async {
                    self?.reloadAssetSection()
                }
            }
            
            let snapshots = SnapshotDAO.shared.getSnapshots(assetId: assetId)
            let userIds: [String] = snapshots
                .filter({ $0.opponentUserFullName == nil })
                .compactMap({ $0.opponentId })
            if userIds.count > 0 {
                for userId in userIds {
                    ConcurrentJobQueue.shared.addJob(job: RefreshUserJob(userIds: [userId]))
                }
            }
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.snapshots = snapshots
                UIView.performWithoutAnimation {
                    weakSelf.tableView.reloadSections(IndexSet(integer: 1), with: .none)
                }
                if showEmptyIndicatorIfEmpty && weakSelf.filteredSnapshots.isEmpty {
                    weakSelf.tableView.tableFooterView = weakSelf.noTransactionIndicator
                } else {
                    weakSelf.tableView.tableFooterView = weakSelf.emptyFooterView
                }
            }
        }
    }
    
    private func reloadAssetSection() {
        guard let asset = asset else {
            return
        }
        if let url = URL(string: asset.iconUrl) {
            iconImageView.sd_setImage(with: url, placeholderImage: #imageLiteral(resourceName: "ic_place_holder"), options: [], completed: nil)
        }
        if let chainIconUrl  = asset.chainIconUrl,  let chainUrl = URL(string: chainIconUrl) {
            blockchainImageView.sd_setImage(with: chainUrl)
            blockchainImageView.isHidden = false
        }
        balanceLabel.text = CurrencyFormatter.localizedString(from: asset.balance, format: .precision, sign: .never, symbol: .custom(asset.symbol))
        exchangeLabel.text = asset.localizedUSDBalance
        depositButton.isBusy = !(asset.isAccount || asset.isAddress)
    }
    
    private func updateFilteredSnapshots() {
        let visibleSnapshotTypes = filterWindow
            .filter
            .snapshotTypes
            .map({ $0.rawValue })
        filteredSnapshots = snapshots
            .filter({ visibleSnapshotTypes.contains($0.type) })
            .sorted(by: filterWindow.sort == .time ? timeSorter : amountSorter)
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
    
}
