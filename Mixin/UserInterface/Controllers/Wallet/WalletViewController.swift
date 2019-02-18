import UIKit
import LocalAuthentication

class WalletViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    private let footerHeight: CGFloat = 10
    
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
        updateTableViewContentInset()
        tableView.register(UINib(nibName: "WalletAssetCell", bundle: .main), forCellReuseIdentifier: ReuseId.asset)
        tableView.register(WalletFooterView.self, forHeaderFooterViewReuseIdentifier: ReuseId.footer)
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
        NotificationCenter.default.addObserver(self, selector: #selector(fetchAssets), name: .AssetsDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(fetchAssets), name: .AssetVisibleDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(fetchAssets), name: .HiddenAssetsDidChange, object: nil)
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
    
    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTableViewContentInset()
    }
    
    @IBAction func backAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func moreAction(_ sender: Any) {
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
        alc.addAction(UIAlertAction(title: Localized.WALLET_SETTING, style: .default, handler: { [weak self](_) in
            self?.navigationController?.pushViewController(WalletSettingViewController.instance(), animated: true)
        }))
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        self.present(alc, animated: true, completion: nil)
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
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 1 ? assets.count : 1
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            let firstUSDBalance: Double
            if let asset = assets.first {
                firstUSDBalance = asset.balance.doubleValue * asset.priceUsd.doubleValue
            } else {
                firstUSDBalance = 0
            }
            return WalletHeaderCell.height(usdBalanceIsMoreThanZero: firstUSDBalance > 0)
        case 1:
            return WalletAssetCell.height
        default:
            return WalletAddAssetCell.height
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: ReuseId.header) as! WalletHeaderCell
            cell.render(assets: assets)
            return cell
        case 1:
            let asset = assets[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: ReuseId.asset) as! WalletAssetCell
            cell.render(asset: asset)
            return cell
        default:
            return tableView.dequeueReusableCell(withIdentifier: ReuseId.addAsset)!
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return section == 1 ? 0 : footerHeight
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == 1 {
            return nil
        } else {
            return tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.footer)
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 1:
            let vc = AssetViewController.instance(asset: assets[indexPath.row])
            navigationController?.pushViewController(vc, animated: true)
        case 2:
            let vc = AddAssetViewController.instance()
            navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
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

extension WalletViewController {
    
    private enum ReuseId {
        static let header = "wallet_header"
        static let asset = "wallet_asset"
        static let addAsset = "wallet_add_asset"
        static let footer = "footer"
    }
    
    private func updateTableViewContentInset() {
        if view.compatibleSafeAreaInsets.bottom < 1 {
            tableView.contentInset.bottom = 10
        } else {
            tableView.contentInset.bottom = 0
        }
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
    
}
