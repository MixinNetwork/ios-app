import UIKit
import LocalAuthentication
import MixinServices

class WalletViewController: UIViewController, MixinNavigationAnimating {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableHeaderView: WalletHeaderView!
    
    private let searchAppearingAnimationDistance: CGFloat = 20
    
    private var searchCenterYConstraint: NSLayoutConstraint?
    private var searchViewController: WalletSearchViewController?
    private var lastSelectedAction: TransferActionView.Action?

    private var isSearchViewControllerPreloaded = false
    private var assets = [AssetItem]()
    private var sendableAssets = [AssetItem]()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    class func presentWallet() {
        guard let navigationController = UIApplication.homeNavigationController else {
            return
        }
        switch TIP.status {
        case .ready, .needsMigrate:
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
        case .needsInitialize:
            let tip = TIPNavigationViewController(intent: .create, destination: .wallet)
            navigationController.present(tip, animated: true)
        case .unknown:
            break
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableHeaderView.transferActionView.delegate = self
        updateTableViewContentInset()
        tableView.register(R.nib.assetCell)
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
        updateTableHeaderVisualEffect()
        NotificationCenter.default.addObserver(self, selector: #selector(fetchAssets), name: AssetDAO.assetsDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(fetchAssets), name: ChainDAO.chainsDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(fetchAssets), name: AppGroupUserDefaults.Wallet.assetVisibilityDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateTableHeaderVisualEffect), name: UIApplication.significantTimeChangeNotification, object: nil)
        fetchAssets()
        ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob(request: .allAssets))
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
        view.layoutIfNeeded()
        UIView.animate(withDuration: 0.5, delay: 0, options: .overdampedCurve) {
            controller.view.alpha = 1
            constraint.constant = 0
            self.view.layoutIfNeeded()
        }
        self.searchViewController = controller
        self.searchCenterYConstraint = constraint
    }
    
    @IBAction func moreAction(_ sender: Any) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: R.string.localizable.all_transactions(), style: .default, handler: { (_) in
            self.navigationController?.pushViewController(AllTransactionsViewController.instance(), animated: true)
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.hidden_assets(), style: .default, handler: { (_) in
            self.navigationController?.pushViewController(HiddenAssetViewController.instance(), animated: true)
        }))
        if WalletConnectService.isAvailable {
            sheet.addAction(UIAlertAction(title: R.string.localizable.connected_dapps(), style: .default, handler: { _ in
                let dapps = ConnectedDappsViewController.instance()
                self.navigationController?.pushViewController(dapps, animated: true)
            }))
        }
        sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
    }
    
    func dismissSearch() {
        guard let searchViewController = searchViewController else {
            return
        }
        UIView.animate(withDuration: 0.5, delay: 0, options: .overdampedCurve) {
            searchViewController.view.alpha = 0
            self.searchCenterYConstraint?.constant = -self.searchAppearingAnimationDistance
            self.view.layoutIfNeeded()
        } completion: { _ in
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
        tableView.deselectRow(at: indexPath, animated: true)
        let vc = AssetViewController.instance(asset: assets[indexPath.row])
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        UISwipeActionsConfiguration(actions: [hideAssetAction(forRowAt: indexPath)])
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }
    
}

extension WalletViewController: TransferActionViewDelegate {
    
    func transferActionView(_ view: TransferActionView, didSelect action: TransferActionView.Action) {
        lastSelectedAction = action
        let controller = TransferSearchViewController()
        controller.delegate = self
        switch action {
        case .send:
            controller.showEmptyHintIfNeeded = true
            controller.searchResultsFromServer = false
            controller.assets = assets.filter { $0.balance != "0" }
            controller.sendableAssets = sendableAssets
        case .receive:
            controller.showEmptyHintIfNeeded = false
            controller.searchResultsFromServer = true
            controller.assets = assets
        }
        present(controller, animated: true, completion: nil)
    }
    
}

extension WalletViewController: TransferSearchViewControllerDelegate {
    
    func transferSearchViewController(_ viewController: TransferSearchViewController, didSelectAsset asset: AssetItem) {
        guard let action = lastSelectedAction else {
            return
        }
        let controller: UIViewController
        switch action {
        case .send:
            controller = AssetViewController.instance(asset: asset, performSendOnAppear: true)
        case .receive:
            if asset.isDepositSupported {
                controller = DepositViewController.instance(asset: asset)
            } else {
                controller = DepositNotSupportedViewController.instance(asset: asset)
            }
        }
        navigationController?.pushViewController(controller, animated: true)
    }
    
    func transferSearchViewControllerDidSelectDeposit(_ viewController: TransferSearchViewController) {
        lastSelectedAction = .receive
        viewController.searchResultsFromServer = true
        viewController.reloadAssets(assets)
    }
    
}

extension WalletViewController {
    
    private func hideAssetAction(forRowAt indexPath: IndexPath) -> UIContextualAction {
        let action = UIContextualAction(style: .destructive, title: R.string.localizable.hide()) { [weak self] (action, _, completionHandler: (Bool) -> Void) in
            guard let self = self else {
                return
            }
            let asset = self.assets[indexPath.row]
            let alert = UIAlertController(title: R.string.localizable.wallet_hide_asset_confirmation(asset.symbol), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: R.string.localizable.hide(), style: .default, handler: { (_) in
                self.hideAsset(of: asset.assetId)
            }))
            self.present(alert, animated: true, completion: nil)
            completionHandler(true)
        }
        action.backgroundColor = .theme
        return action
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
            let allAssets = AssetDAO.shared.getAssets()
            let hiddenAssetIds = AppGroupUserDefaults.Wallet.hiddenAssetIds
            let assets = allAssets.filter { hiddenAssetIds[$0.assetId] == nil }
            let sendableAssets = allAssets.filter { $0.balance != "0" }
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.assets = assets
                self.sendableAssets = sendableAssets
                self.tableHeaderView.render(assets: assets)
                self.tableHeaderView.sizeToFit()
                self.tableView.reloadData()
            }
        }
    }
    
    @objc private func updateTableHeaderVisualEffect() {
        let now = Date()
        let showSnowfall = now.isChristmas || now.isChineseNewYear
        tableHeaderView.showSnowfallEffect = showSnowfall
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
