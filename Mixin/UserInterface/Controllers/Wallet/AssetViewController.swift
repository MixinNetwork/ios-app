import UIKit

class AssetViewController: UITableViewController {

    private var asset: AssetItem!
    private var snapshots = [SnapshotItem]()

    @IBOutlet weak var iconImageView: AvatarImageView!
    @IBOutlet weak var blockchainImageView: CornerImageView!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var exchangeLabel: UILabel!
    @IBOutlet weak var depositButton: StateResponsiveButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "SnapshotCell", bundle: .main),
                           forCellReuseIdentifier: SnapshotCell.cellIdentifier)
        updateUI()
        fetchAsset()
        addObservers()
        ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob(assetId: asset.assetId))
        ConcurrentJobQueue.shared.addJob(job: RefreshSnapshotsJob(assetId: asset.assetId))
    }

    private func addObservers() {
        let callback = { [weak self] (notification: Notification) in
            guard let weakSelf = self, let assetId = notification.object as? String, assetId == weakSelf.asset.assetId else {
                return
            }
            self?.fetchAsset()
        }
        NotificationCenter.default.addObserver(forName: .AssetsDidChange, object: nil, queue: .main, using: callback)
        NotificationCenter.default.addObserver(forName: .SnapshotDidChange, object: nil, queue: .main, using: callback)
    }

    @IBAction func depositAction(_ sender: Any) {
        guard !depositButton.isBusy else {
            return
        }
        navigationController?.pushViewController(TransferInViewController.instance(asset: asset), animated: true)
    }
    
    private func fetchAsset() {
        let assetId = asset.assetId
        DispatchQueue.global().async { [weak self] in
            if let asset = AssetDAO.shared.getAsset(assetId: assetId) {
                self?.asset = asset
                DispatchQueue.main.async {
                    self?.updateUI()
                }
            }

            let snapshots = SnapshotDAO.shared.getSnapshots(assetId: assetId)
            let userIds: [String] = snapshots.filter({ (snapshot) -> Bool in
                return snapshot.opponentUserFullName == nil && snapshot.opponentId != nil
            }).flatMap({ (snapshot) -> String in
                return snapshot.opponentId!
            })
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
            }
        }
    }

    private func updateUI() {
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
        balanceLabel.text = String(format: "%@ %@", asset.balance.formatFullBalance(), asset.symbol)
        exchangeLabel.text = asset.getUSDBalance()
        depositButton.isBusy = asset.publicKey.isEmpty
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
            return snapshots.count
        } else {
            return super.tableView(tableView, numberOfRowsInSection: section)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: SnapshotCell.cellIdentifier, for: indexPath) as! SnapshotCell
            cell.render(snapshot: snapshots[indexPath.row])
            return cell
        } else {
            return super.tableView(tableView, cellForRowAt: indexPath)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 1 else {
            return
        }
        
        navigationController?.pushViewController(TransactionViewController.instance(asset: asset, snapshot: snapshots[indexPath.row]), animated: true)

    }
}
    
extension AssetViewController {

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard section == 1 && snapshots.count > 0 else {
            return nil
        }
        return Localized.TRANSFER_TRANSACTIONS
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 1 {
            return SnapshotCell.cellHeight
        } else {
            return super.tableView(tableView, heightForRowAt: indexPath)
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
