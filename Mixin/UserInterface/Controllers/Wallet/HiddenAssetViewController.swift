import UIKit

class HiddenAssetViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    private var assets = [AssetItem]()

    override func viewDidLoad() {
        super.viewDidLoad()
        prepareTableView()
        fetchAssets()
    }

    private func prepareTableView() {
        tableView.register(UINib(nibName: "WalletAssetCell", bundle: nil), forCellReuseIdentifier: WalletAssetCell.cellIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.reloadData()
        NotificationCenter.default.addObserver(forName: .AssetVisibleDidChange, object: nil, queue: .main) { [weak self] (_) in
            self?.fetchAssets()
        }
    }

    private func fetchAssets() {
        DispatchQueue.global().async { [weak self] in
            let hiddenAssets = WalletUserDefault.shared.hiddenAssets
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
        container.automaticallyAdjustsScrollViewInsets = false
        return container
    }
}

extension HiddenAssetViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return assets.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return WalletAssetCell.cellHeight
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let asset = assets[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: WalletAssetCell.cellIdentifier) as! WalletAssetCell
        cell.render(asset: asset)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        navigationController?.pushViewController(AssetViewController.instance(asset: assets[indexPath.row]), animated: true)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
    
}

