import UIKit
import LocalAuthentication

class WalletViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableHeaderView: WalletHeaderView!
    
    private var assets = [AssetItem]()
    
    private lazy var assetActions: [UITableViewRowAction] = {
        let action = UITableViewRowAction(style: .destructive, title: Localized.ACTION_HIDE, handler: { [weak self] (_, indexPath) in
            self?.confirmHideAsset(at: indexPath)
        })
        action.backgroundColor = .theme
        return [action]
    }()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    class func instance() -> UIViewController {
        return ContainerViewController.instance(viewController: R.storyboard.wallet.instantiateInitialViewController()!, title: Localized.WALLET_TITLE)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateTableViewContentInset()
        tableView.register(R.nib.assetCell)
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
        NotificationCenter.default.addObserver(self, selector: #selector(fetchAssets), name: .AssetsDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(fetchAssets), name: .AssetVisibleDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(fetchAssets), name: .HiddenAssetsDidChange, object: nil)
        fetchAssets()
        ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob())
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTableViewContentInset()
    }
    
}

extension WalletViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.WALLET_TITLE_ADD_ASSET, style: .default, handler: { [weak self](_) in
            self?.navigationController?.pushViewController(AddAssetViewController.instance(), animated: true)
        }))
        alc.addAction(UIAlertAction(title: Localized.WALLET_ALL_TRANSACTIONS_TITLE, style: .default, handler: { [weak self](_) in
            self?.navigationController?.pushViewController(AllTransactionsViewController.instance(), animated: true)
        }))
        alc.addAction(UIAlertAction(title: Localized.WALLET_MENU_SHOW_HIDDEN_ASSETS, style: .default, handler: { [weak self](_) in
            self?.navigationController?.pushViewController(HiddenAssetViewController.instance(), animated: true)
        }))
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        self.present(alc, animated: true, completion: nil)
    }
    
    func imageBarRightButton() -> UIImage? {
        return R.image.ic_title_more()
    }
    
}

extension WalletViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? assets.count : 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return AssetCell.height
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let asset = assets[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.asset, for: indexPath)!
            cell.render(asset: asset)
            return cell
        default:
            return tableView.dequeueReusableCell(withIdentifier: ReuseId.addAsset)!
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            let vc = AssetViewController.instance(asset: assets[indexPath.row])
            navigationController?.pushViewController(vc, animated: true)
        default:
            let vc = AddAssetViewController.instance()
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if indexPath.section == 0 {
            return assetActions
        } else {
            return []
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 0
    }
    
}

extension WalletViewController {
    
    private enum ReuseId {
        static let addAsset = "wallet_add_asset"
    }
    
    private func updateTableViewContentInset() {
        if view.safeAreaInsets.bottom < 1 {
            tableView.contentInset.bottom = 10
        } else {
            tableView.contentInset.bottom = 0
        }
    }
    
    @objc private func fetchAssets() {
        DispatchQueue.global().async { [weak self] in
            let hiddenAssets = AppGroupUserDefaults.Wallet.hiddenAssetIds
            let assets = AssetDAO.shared.getAssets().filter({ (asset) -> Bool in
                return hiddenAssets[asset.assetId] == nil
            })
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.assets = assets
                weakSelf.tableHeaderView.render(assets: assets)
                weakSelf.tableHeaderView.sizeToFit()
                weakSelf.tableView.reloadData()
            }
        }
    }
    
    private func confirmHideAsset(at indexPath: IndexPath) {
        let asset = assets[indexPath.row]
        let alert = UIAlertController(title: R.string.localizable.wallet_hide_asset_confirmation(asset.symbol), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.action_hide(), style: .default, handler: { (_) in
            self.hideAsset(of: asset.assetId)
        }))
        present(alert, animated: true, completion: nil)
    }
    
    private func hideAsset(of assetId: String) {
        guard let index = assets.firstIndex(where: { $0.assetId == assetId }) else {
            return
        }
        assets.remove(at: index)
        tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .fade)
        AppGroupUserDefaults.Wallet.hiddenAssetIds[assetId] = true
    }
    
}
