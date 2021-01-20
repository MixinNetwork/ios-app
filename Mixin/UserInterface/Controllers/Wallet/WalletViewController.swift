import UIKit
import LocalAuthentication
import MixinServices

class WalletViewController: UIViewController, MixinNavigationAnimating {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableHeaderView: WalletHeaderView!
    
    private let searchAppearingAnimationDistance: CGFloat = 20
    
    private var searchCenterYConstraint: NSLayoutConstraint?
    private var searchViewController: WalletSearchViewController?
    
    private var isSearchViewControllerPreloaded = false
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
    
    class func presentWallet() {
        guard let account = LoginManager.shared.account else {
            return
        }
        guard let navigationController = UIApplication.homeNavigationController else {
            return
        }

        if account.has_pin {
            let shouldValidatePin: Bool
            if let date = AppGroupUserDefaults.Wallet.lastPinVerifiedDate {
                shouldValidatePin = -date.timeIntervalSinceNow > AppGroupUserDefaults.Wallet.periodicPinVerificationInterval
            } else {
                AppGroupUserDefaults.Wallet.periodicPinVerificationInterval = PeriodicPinVerificationInterval.min
                shouldValidatePin = true
            }
            
            let wallet = R.storyboard.wallet.wallet()!
            if shouldValidatePin {
                let validator = PinValidationViewController(onSuccess: { (_) in
                    navigationController.pushViewController(withBackRoot: wallet)
                })
                UIApplication.homeViewController?.present(validator, animated: true, completion: nil)
            } else {
                navigationController.pushViewController(withBackRoot: wallet)
            }
        } else {
            navigationController.pushViewController(withBackRoot: WalletPasswordViewController.instance(walletPasswordType: .initPinStep1, dismissTarget: .wallet))
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateTableViewContentInset()
        tableView.register(R.nib.assetCell)
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
        NotificationCenter.default.addObserver(self, selector: #selector(fetchAssets), name: AssetDAO.assetsDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(fetchAssets), name: Application.assetVisibilityDidChangeNotification, object: nil)
        fetchAssets()
        ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob())
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !isSearchViewControllerPreloaded {
            let controller = R.storyboard.wallet.wallet_search()!
            controller.loadViewIfNeeded()
            isSearchViewControllerPreloaded = true
        }
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTableViewContentInset()
    }
    
    @IBAction func backAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func searchAction(_ sender: Any) {
        let controller = R.storyboard.wallet.wallet_search()!
        controller.view.alpha = 0
        addChild(controller)
        view.addSubview(controller.view)
        controller.view.snp.makeConstraints { (make) in
            make.size.equalTo(view.snp.size)
            make.centerX.equalToSuperview()
        }
        let constraint = controller.view.centerYAnchor.constraint(equalTo: view.centerYAnchor,
                                                                  constant: -searchAppearingAnimationDistance)
        constraint.isActive = true
        controller.didMove(toParent: self)
        self.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.5) {
            UIView.setAnimationCurve(.overdamped)
            controller.view.alpha = 1
            constraint.constant = 0
            self.view.layoutIfNeeded()
        }
        self.searchViewController = controller
        self.searchCenterYConstraint = constraint
    }
    
    @IBAction func moreAction(_ sender: Any) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: R.string.localizable.wallet_all_transactions_title(), style: .default, handler: { (_) in
            self.navigationController?.pushViewController(AllTransactionsViewController.instance(), animated: true)
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.wallet_menu_show_hidden_assets(), style: .default, handler: { (_) in
            self.navigationController?.pushViewController(HiddenAssetViewController.instance(), animated: true)
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
    }
    
    func dismissSearch() {
        guard let searchViewController = searchViewController else {
            return
        }
        UIView.animate(withDuration: 0.5) {
            UIView.setAnimationCurve(.overdamped)
            searchViewController.view.alpha = 0
            self.searchCenterYConstraint?.constant = -self.searchAppearingAnimationDistance
            self.view.layoutIfNeeded()
        } completion: { (_) in
            searchViewController.willMove(toParent: nil)
            searchViewController.view.removeFromSuperview()
            searchViewController.removeFromParent()
        }
    }
    
}

extension WalletViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        assets.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        AssetCell.height
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let asset = assets[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.asset, for: indexPath)!
        cell.render(asset: asset)
        return cell
    }
    
}

extension WalletViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc = AssetViewController.instance(asset: assets[indexPath.row])
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        assetActions
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }
    
}

extension WalletViewController {
    
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
