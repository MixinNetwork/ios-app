import UIKit
import MixinServices

final class PrivacyWalletViewController: WalletViewController {
    
    private var tokens: [MixinTokenItem] = []
    private var lastSelectedAction: TokenAction?
    private var hasAssetInLegacyNetwork = false
    
    private weak var walletSwitchBadgeView: BadgeDotView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = R.string.localizable.privacy_wallet()
        let privacyIconView = UIImageView(image: R.image.privacy_wallet())
        privacyIconView.contentMode = .center
        privacyIconView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        privacyIconView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        titleInfoStackView.addArrangedSubview(privacyIconView)
        
        tableHeaderView.actionView.delegate = self
        tableHeaderView.pendingDepositButton.addTarget(
            self,
            action: #selector(revealPendingDeposits(_:)),
            for: .touchUpInside
        )
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
        
        let notificationCenter: NotificationCenter = .default
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadData),
            name: TokenDAO.tokensDidChangeNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadData),
            name: ChainDAO.chainsDidChangeNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadData),
            name: TokenExtraDAO.tokenVisibilityDidChangeNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadData),
            name: UTXOService.balanceDidUpdateNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadPendingDeposits),
            name: UTXOService.balanceDidUpdateNotification,
            object: nil
        )
        reloadData()
        
        DispatchQueue.global().async {
            let hasWalletSwitchViewed: Bool = PropertiesDAO.shared.value(forKey: .hasWalletSwitchViewed) ?? false
            guard !hasWalletSwitchViewed else {
                return
            }
            DispatchQueue.main.async {
                let badge = BadgeDotView()
                self.titleView.addSubview(badge)
                badge.snp.makeConstraints { make in
                    make.top.equalTo(self.walletSwitchImageView)
                    make.leading.equalTo(self.walletSwitchImageView.snp.trailing).offset(-2)
                }
                self.walletSwitchBadgeView = badge
                notificationCenter.addObserver(
                    self,
                    selector: #selector(self.hideBadgeView(_:)),
                    name: PropertiesDAO.propertyDidUpdateNotification,
                    object: nil
                )
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadPendingDeposits()
        DispatchQueue.global().async {
            let hasAssetInLegacyNetwork = AssetDAO.shared.hasPositiveBalancedAssets()
            DispatchQueue.main.async {
                self.hasAssetInLegacyNetwork = hasAssetInLegacyNetwork
            }
        }
    }
    
    override func moreAction(_ sender: Any) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: R.string.localizable.all_transactions(), style: .default, handler: { (_) in
            let history = MixinTransactionHistoryViewController(type: nil)
            self.navigationController?.pushViewController(history, animated: true)
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.hidden_assets(), style: .default, handler: { (_) in
            self.navigationController?.pushViewController(HiddenMixinTokensViewController(), animated: true)
        }))
        if hasAssetInLegacyNetwork {
            sheet.addAction(UIAlertAction(title: R.string.localizable.legacy_network(), style: .default, handler: performAssetMigration(_:)))
        }
        sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
    }
    
    @objc private func reloadData() {
        DispatchQueue.global().async { [weak self] in
            let tokens = TokenDAO.shared.notHiddenTokens()
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.tokens = tokens
                self.tableHeaderView.reloadValues(tokens: tokens)
                self.layoutTableHeaderView()
                self.tableView.reloadData()
            }
        }
    }
    
    @objc private func reloadPendingDeposits() {
        DispatchQueue.global().async { [weak self] in
            let pendingSnapshots = SafeSnapshotDAO.shared.snapshots(assetID: nil, pending: true, limit: nil)
            let assetIDs = Set(pendingSnapshots.map(\.assetID))
            let tokens = TokenDAO.shared.tokens(with: assetIDs)
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.tableHeaderView.reloadPendingDeposits(tokens: tokens, snapshots: pendingSnapshots)
                self.layoutTableHeaderView()
            }
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
                let assetIDs = Set(myDeposits.map(\.assetID))
                
                var tokens = TokenDAO.shared.tokens(with: assetIDs)
                let missingAssetIDs = TokenDAO.shared.inexistAssetIDs(in: assetIDs)
                if !missingAssetIDs.isEmpty {
                    switch SafeAPI.assets(ids: missingAssetIDs) {
                    case .failure(let error):
                        Logger.general.debug(category: "Wallet", message: "\(error)")
                    case .success(let missingTokens):
                        TokenDAO.shared.save(assets: missingTokens)
                        tokens.append(contentsOf: missingTokens)
                    }
                }
                
                SafeSnapshotDAO.shared.replaceAllPendingSnapshots(with: myDeposits)
                let snapshots = myDeposits.map(SafeSnapshot.init(pendingDeposit:))
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }
                    self.tableHeaderView.reloadPendingDeposits(tokens: tokens, snapshots: snapshots)
                    self.layoutTableHeaderView()
                }
            }
        }
    }
    
    @objc private func revealPendingDeposits(_ sender: Any) {
        let transactionHistory = MixinTransactionHistoryViewController(type: .pending)
        navigationController?.pushViewController(transactionHistory, animated: true)
    }
    
    @objc private func hideBadgeView(_ notification: Notification) {
        guard let change = notification.userInfo?[PropertiesDAO.Key.hasWalletSwitchViewed] as? PropertiesDAO.Change else {
            return
        }
        let hasReviewed = switch change {
        case .saved(let newValue):
            (newValue as? Bool) ?? false
        case .removed:
            false
        }
        if hasReviewed {
            walletSwitchBadgeView?.removeFromSuperview()
        }
    }
    
    private func performAssetMigration(_ sender: Any) {
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
    
}

extension PrivacyWalletViewController: HomeTabBarControllerChild {
    
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

extension PrivacyWalletViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tokens.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let token = tokens[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.asset, for: indexPath)!
        cell.render(token: token)
        return cell
    }
    
}

extension PrivacyWalletViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let token = tokens[indexPath.row]
        let viewController = MixinTokenViewController(token: token)
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(
            style: .destructive,
            title: R.string.localizable.hide()
        ) { [weak self] (action, _, completionHandler) in
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
        action.backgroundColor = R.color.theme()
        return UISwipeActionsConfiguration(actions: [action])
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }
    
}

extension PrivacyWalletViewController: TokenActionView.Delegate {
    
    func tokenActionView(_ view: TokenActionView, wantsToPerformAction action: TokenAction) {
        lastSelectedAction = action
        switch action {
        case .send:
            let selector = SendTokenSelectorViewController()
            selector.onSelected = { token in
                let receiver = TokenReceiverViewController(token: token)
                self.navigationController?.pushViewController(receiver, animated: true)
            }
            present(selector, animated: true, completion: nil)
        case .receive:
            let controller = TransferSearchViewController()
            controller.delegate = self
            controller.showEmptyHintIfNeeded = false
            controller.searchResultsFromServer = true
            controller.tokens = tokens
            withMnemonicsBackupChecked {
                self.present(controller, animated: true, completion: nil)
            }
        case .swap:
            tableHeaderView.actionView.badgeOnSwap = false
            let swap = MixinSwapViewController(sendAssetID: nil, receiveAssetID: nil)
            navigationController?.pushViewController(swap, animated: true)
            DispatchQueue.global().async {
                PropertiesDAO.shared.set(true, forKey: .hasSwapReviewed)
            }
            reporter.report(event: .swapStart, tags: ["entrance": "wallet", "source": "mixin"])
        }
    }
    
}

extension PrivacyWalletViewController: TransferSearchViewControllerDelegate {
    
    func transferSearchViewController(_ viewController: TransferSearchViewController, didSelectToken token: MixinTokenItem) {
        guard let action = lastSelectedAction else {
            return
        }
        let controller: UIViewController
        switch action {
        case .send:
            controller = MixinTokenViewController(token: token, performSendOnAppear: true)
        case .receive:
            controller = DepositViewController(token: token)
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
