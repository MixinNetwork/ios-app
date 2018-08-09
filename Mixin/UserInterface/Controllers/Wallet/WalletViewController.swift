import UIKit
import LocalAuthentication

class WalletViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    private var assets = [AssetItem]()
    private var pinView: PinTipsView?

    private lazy var assetAction: UITableViewRowAction = {
        let action = UITableViewRowAction(style: .destructive, title: Localized.ACTION_HIDE, handler: { [weak self] (_, indexPath) in
            guard let weakSelf = self else {
                return
            }
            let assetId = weakSelf.assets[indexPath.row].assetId
            weakSelf.assets.remove(at: indexPath.row)
            weakSelf.tableView.deleteRows(at: [indexPath], with: .fade)
            WalletUserDefault.shared.hiddenAssets[assetId] = assetId
        })
        action.backgroundColor = .actionBackground
        return action
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        prepareTableView()
        fetchAssets()
        fetchRemoteAssets()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if Date().timeIntervalSince1970 - WalletUserDefault.shared.lastInputPinTime > WalletUserDefault.shared.checkPinInterval {
            PinTipsView.instance().presentPopupControllerAnimated()
        }
    }

    private func prepareTableView() {
        tableView.register(UINib(nibName: "WalletAssetCell", bundle: nil), forCellReuseIdentifier: WalletAssetCell.cellIdentifier)
        tableView.register(UINib(nibName: "WalletTotalBalanceCell", bundle: nil), forCellReuseIdentifier: WalletTotalBalanceCell.cellIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.reloadData()
        NotificationCenter.default.addObserver(self, selector: #selector(fetchAssets), name: .AssetsDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(fetchAssets), name: .AssetVisibleDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(fetchAssets), name: .HiddenAssetsDidChange, object: nil)
    }

    @objc private func fetchAssets() {
        DispatchQueue.global().async { [weak self] in
            let hiddenAssets = WalletUserDefault.shared.hiddenAssets
            let assets = AssetDAO.shared.getAssets().filter({ (asset) -> Bool in
                return hiddenAssets[asset.assetId] == nil
            })
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.assets = assets
                weakSelf.tableView.reloadData()
            }
        }
    }

    private func fetchRemoteAssets() {
        DispatchQueue.global().async {
            switch AssetAPI.shared.assets() {
            case let .success(assets):
                DispatchQueue.global().async {
                    AssetDAO.shared.insertOrUpdateAssets(assets: assets)
                }
            case .failure:
                break
            }
        }
    }

    @IBAction func backAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func moreAction(_ sender: Any) {
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.WALLET_ALL_TRANSACTIONS_TITLE, style: .default, handler: { [weak self](_) in
            self?.navigationController?.pushViewController(SnapshotViewController.instance(), animated: true)
        }))
        alc.addAction(UIAlertAction(title: Localized.WALLET_MENU_SHOW_HIDDEN_ASSETS, style: .default, handler: { [weak self](_) in
            self?.navigationController?.pushViewController(HiddenAssetViewController.instance(), animated: true)
        }))
        if #available(iOS 11.0, *), let biometryType = getBiometryType() {
            alc.addAction(UIAlertAction(title: Localized.WALLET_SETTING, style: .default, handler: { [weak self](_) in                self?.navigationController?.pushViewController(WalletSettingViewController.instance(biometryType: biometryType), animated: true)
            }))
        } else {
            alc.addAction(UIAlertAction(title: Localized.WALLET_CHANGE_PASSWORD, style: .default, handler: { [weak self](_) in
                let vc = WalletPasswordViewController.instance(walletPasswordType: .changePinStep1)
                self?.navigationController?.pushViewController(vc, animated: true)
            }))
        }
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        self.present(alc, animated: true, completion: nil)
    }

    @available(iOS 11.0, *)
    private func getBiometryType() -> LABiometryType? {
        guard AccountAPI.shared.account?.has_pin ?? false else {
            return nil
        }
        guard !UIDevice.isJailbreak else {
            return nil
        }

        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            if context.biometryType == .touchID || context.biometryType == .faceID {
                return context.biometryType
            }
        }
        return nil
    }

    class func instance() -> UIViewController {
        return Storyboard.wallet.instantiateInitialViewController()!
    }
}

extension WalletViewController: MixinNavigationAnimating {
    
    var pushAnimation: MixinNavigationPushAnimation {
        return .reversedPush
    }
    
    var popAnimation: MixinNavigationPopAnimation {
        return .reversedPop
    }

}

extension WalletViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : assets.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 0 ? WalletTotalBalanceCell.cellHeight : WalletAssetCell.cellHeight
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: WalletTotalBalanceCell.cellIdentifier) as! WalletTotalBalanceCell
            cell.render(assets: assets)
            return cell
        } else {
            let asset = assets[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: WalletAssetCell.cellIdentifier) as! WalletAssetCell
            cell.render(asset: asset)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 1 {
            navigationController?.pushViewController(AssetViewController.instance(asset: assets[indexPath.row]), animated: true)
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? CGFloat.leastNormalMagnitude : 10
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 10
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard indexPath.section == 1 else {
            return []
        }
        return [assetAction]
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 1
    }
}

