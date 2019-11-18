import UIKit

class HiddenAssetViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    private var assets = [AssetItem]()

    private lazy var assetAction: UITableViewRowAction = {
        let action = UITableViewRowAction(style: .destructive, title: Localized.ACTION_SHOW, handler: { [weak self] (_, indexPath) in
            guard let weakSelf = self else {
                return
            }
            let assetId = weakSelf.assets[indexPath.row].assetId
            weakSelf.assets.remove(at: indexPath.row)
            weakSelf.tableView.deleteRows(at: [indexPath], with: .fade)
            AppGroupUserDefaults.Wallet.hiddenAssetIds[assetId] = nil
        })
        action.backgroundColor = .theme
        return action
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateTableViewContentInset()
        tableView.register(R.nib.assetCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.reloadData()
        NotificationCenter.default.addObserver(self, selector: #selector(fetchAssets), name: .AssetVisibleDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(fetchAssets), name: .HiddenAssetsDidChange, object: nil)
        fetchAssets()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTableViewContentInset()
    }
    
    @objc private func fetchAssets() {
        DispatchQueue.global().async { [weak self] in
            let hiddenAssets = AppGroupUserDefaults.Wallet.hiddenAssetIds
            let assets = AssetDAO.shared.getAssets().filter({ (asset) -> Bool in
                return hiddenAssets[asset.assetId] != nil
            })
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.assets = assets
                weakSelf.tableView.reloadData()
                weakSelf.tableView.checkEmpty(dataCount: assets.count, text: Localized.WALLET_HIDE_ASSET_EMPTY, photo: #imageLiteral(resourceName: "ic_empty_hidden_assets"))
            }
        }
    }

    @IBAction func backAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    class func instance() -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "hidden_assets")
        let container = ContainerViewController.instance(viewController: vc, title: Localized.WALLET_MENU_SHOW_HIDDEN_ASSETS)
        return container
    }
    
    private func updateTableViewContentInset() {
        if view.safeAreaInsets.bottom < 1 {
            tableView.contentInset.bottom = 10
        } else {
            tableView.contentInset.bottom = 0
        }
    }
    
}

extension HiddenAssetViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return assets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let asset = assets[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.asset, for: indexPath)!
        cell.render(asset: asset)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(AssetViewController.instance(asset: assets[indexPath.row]), animated: true)
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [assetAction]
    }
    
}

extension HiddenAssetViewController: ContainerViewControllerDelegate {
    
    var prefersNavigationBarSeparatorLineHidden: Bool {
        return true
    }
    
}
