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
    private var tokens = [TokenItem]()
    private var sendableTokens = [TokenItem]()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableHeaderView.transferActionView.actions = [.send, .receive, .swap]
        tableHeaderView.transferActionView.delegate = self
        updateTableViewContentInset()
        tableView.register(R.nib.assetCell)
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
        updateTableHeaderVisualEffect()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: TokenDAO.tokensDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: ChainDAO.chainsDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: TokenExtraDAO.tokenVisibilityDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: UTXOService.balanceDidUpdateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateTableHeaderVisualEffect), name: UIApplication.significantTimeChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dismissSearch), name: dismissSearchNotification, object: nil)
        reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let navigationController, !navigationController.isNavigationBarHidden {
            navigationController.setNavigationBarHidden(true, animated: true)
        }
        DispatchQueue.global().async {
            let canMigrateAssets = AssetDAO.shared.hasPositiveBalancedAssets()
            DispatchQueue.main.async {
                if canMigrateAssets {
                    self.tableHeaderView.insertMigrationButtonIfNeeded { button in
                        button.addTarget(self, action: #selector(self.performAssetMigration(_:)), for: .touchUpInside)
                    }
                } else {
                    self.tableHeaderView.removeMigrationButton()
                }
                self.tableHeaderView.sizeToFit()
                self.tableView.tableHeaderView = self.tableHeaderView // Update tableView's layout after resizing
            }
        }
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
    
    @IBAction func scanQRCode() {
        UIApplication.homeNavigationController?.pushCameraViewController(asQRCodeScanner: true)
    }
    
    @IBAction func moreAction(_ sender: Any) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: R.string.localizable.all_transactions(), style: .default, handler: { (_) in
            self.reloadPendingDeposits()
            let history = TransactionHistoryViewController.contained()
            self.navigationController?.pushViewController(history, animated: true)
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.hidden_assets(), style: .default, handler: { (_) in
            self.navigationController?.pushViewController(HiddenTokensViewController.instance(), animated: true)
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
    }
    
    @objc func dismissSearch() {
        guard let searchViewController = searchViewController, searchViewController.parent != nil else {
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
        tokens.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        AssetCell.height
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let asset = tokens[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.asset, for: indexPath)!
        cell.render(asset: asset)
        return cell
    }
    
}

extension WalletViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let token = tokens[indexPath.row]
        let viewController = TokenViewController.contained(token: token)
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(style: .destructive, title: R.string.localizable.hide()) { [weak self] (action, _, completionHandler) in
            guard let self = self else {
                return
            }
            let token = self.tokens[indexPath.row]
            let alert = UIAlertController(title: R.string.localizable.wallet_hide_asset_confirmation(token.symbol), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: R.string.localizable.hide(), style: .default, handler: { (_) in
                self.hideToken(with: token.assetID)
            }))
            self.present(alert, animated: true, completion: nil)
            completionHandler(true)
        }
        action.backgroundColor = .theme
        return UISwipeActionsConfiguration(actions: [action])
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }
    
}

extension WalletViewController: TransferActionViewDelegate {
    
    func transferActionView(_ view: TransferActionView, didSelect action: TransferActionView.Action) {
        lastSelectedAction = action
        switch action {
        case .send:
            let controller = TransferSearchViewController()
            controller.delegate = self
            controller.showEmptyHintIfNeeded = true
            controller.searchResultsFromServer = false
            controller.tokens = tokens.filter { $0.balance != "0" }
            controller.sendableAssets = sendableTokens
            present(controller, animated: true, completion: nil)
        case .receive:
            let controller = TransferSearchViewController()
            controller.delegate = self
            controller.showEmptyHintIfNeeded = false
            controller.searchResultsFromServer = true
            controller.tokens = tokens
            present(controller, animated: true, completion: nil)
        case .swap:
            let swap = MixinSwapViewController.contained(sendAssetID: nil, receiveAssetID: nil)
            navigationController?.pushViewController(swap, animated: true)
        }
    }
    
}

extension WalletViewController: TransferSearchViewControllerDelegate {
    
    func transferSearchViewController(_ viewController: TransferSearchViewController, didSelectToken token: TokenItem) {
        guard let action = lastSelectedAction else {
            return
        }
        let controller: UIViewController
        switch action {
        case .send:
            controller = TokenViewController.contained(token: token, performSendOnAppear: true)
        case .receive:
            controller = DepositViewController.instance(token: token)
        case .swap:
            return
        }
        navigationController?.pushViewController(controller, animated: true)
    }
    
    func transferSearchViewControllerDidSelectDeposit(_ viewController: TransferSearchViewController) {
        lastSelectedAction = .receive
        viewController.searchResultsFromServer = true
        viewController.reload(tokens: tokens)
    }
    
}

extension WalletViewController: HomeTabBarControllerChild {
    
    func viewControllerDidSwitchToFront() {
        let jobs = [
            RefreshAssetsJob(request: .allAssets),
            RefreshAllTokensJob(),
            SyncSafeSnapshotJob(),
            SyncOutputsJob()
        ]
        for job in jobs {
            ConcurrentJobQueue.shared.addJob(job: job)
        }
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
    
    @objc private func reloadData() {
        DispatchQueue.global().async { [weak self] in
            let tokens = TokenDAO.shared.notHiddenTokens()
            let sendableTokens = TokenDAO.shared.positiveBalancedTokens()
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.tokens = tokens
                self.sendableTokens = sendableTokens
                self.tableHeaderView.render(tokens: tokens)
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
    
    @objc private func performAssetMigration(_ sender: Any) {
        let botUserID = "84c9dfb1-bfcf-4cb4-8404-cc5a1354005b"
        let conversationID = ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: botUserID)
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        UserAPI.showUser(userId: botUserID) { response in
            switch response {
            case let .success(response):
                hud.hide()
                UserDAO.shared.updateUsers(users: [response])
                if let app = response.app, let container = UIApplication.homeContainerViewController?.homeTabBarController {
                    MixinWebViewController.presentInstance(with: .init(conversationId: conversationID, app: app), asChildOf: container)
                }
            case .failure:
                hud.set(style: .error, text: R.string.localizable.network_connection_lost())
                hud.scheduleAutoHidden()
            }
        }
    }
    
    private func hideToken(with assetID: String) {
        guard let index = tokens.firstIndex(where: { $0.assetID == assetID }) else {
            return
        }
        let token = tokens.remove(at: index)
        tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .fade)
        DispatchQueue.global().async {
            let extra = TokenExtra(assetID: token.assetID,
                                   kernelAssetID: token.kernelAssetID,
                                   isHidden: true,
                                   balance: token.balance,
                                   updatedAt: Date().toUTCString())
            TokenExtraDAO.shared.insertOrUpdateHidden(extra: extra)
        }
    }
    
    private func reloadPendingDeposits() {
        SafeAPI.allDeposits(queue: .global()) { result in
            guard case .success(let deposits) = result else {
                return
            }
            let entries = DepositEntryDAO.shared.compactEntries()
            let myDeposits = deposits.filter { deposit in
                // `SafeAPI.allDeposits` returns all deposits, whether it's mine or other's
                // Filter with my entries to get my deposits
                entries.contains(where: { (entry) in
                    let isDestinationMatch = entry.destination == deposit.destination
                    let isTagMatch: Bool
                    if entry.tag.isNilOrEmpty && deposit.tag.isNilOrEmpty {
                        isTagMatch = true
                    } else if entry.tag == deposit.tag {
                        isTagMatch = true
                    } else {
                        isTagMatch = false
                    }
                    return isDestinationMatch && isTagMatch
                })
            }
            SafeSnapshotDAO.shared.replaceAllPendingSnapshots(with: myDeposits)
        }
    }
    
}
