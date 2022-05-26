import UIKit
import MixinServices

class HiddenAssetViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    private var assets = [AssetItem]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateTableViewContentInset()
        tableView.register(R.nib.assetCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.reloadData()
        NotificationCenter.default.addObserver(self, selector: #selector(fetchAssets), name: AppGroupUserDefaults.Wallet.assetVisibilityDidChangeNotification, object: nil)
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
                weakSelf.tableView.checkEmpty(dataCount: assets.count,
                                              text: R.string.localizable.no_hidden_asset(),
                                              photo: R.image.emptyIndicator.ic_hidden_assets()!)
            }
        }
    }

    @IBAction func backAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    class func instance() -> UIViewController {
        let vc = R.storyboard.wallet.hidden_assets()!
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.hide_asset())
        return container
    }
    
    private func updateTableViewContentInset() {
        if view.safeAreaInsets.bottom < 1 {
            tableView.contentInset.bottom = 10
        } else {
            tableView.contentInset.bottom = 0
        }
    }
    
    private func showAssetAction(forRowAt indexPath: IndexPath) -> UIContextualAction {
        let action = UIContextualAction(style: .destructive, title: R.string.localizable.show()) { [weak self] (action, _, completionHandler: (Bool) -> Void) in
            guard let self = self else {
                return
            }
            let assetId = self.assets[indexPath.row].assetId
            self.assets.remove(at: indexPath.row)
            self.tableView.deleteRows(at: [indexPath], with: .fade)
            AppGroupUserDefaults.Wallet.hiddenAssetIds[assetId] = nil
            completionHandler(true)
        }
        action.backgroundColor = .theme
        return action
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
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        UISwipeActionsConfiguration(actions: [showAssetAction(forRowAt: indexPath)])
    }
    
}

extension HiddenAssetViewController: ContainerViewControllerDelegate {
    
    var prefersNavigationBarSeparatorLineHidden: Bool {
        return true
    }
    
}
