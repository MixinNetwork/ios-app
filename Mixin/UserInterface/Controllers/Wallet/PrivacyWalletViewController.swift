import UIKit
import MixinServices

final class PrivacyWalletViewController: WalletViewController {
    
    private var tokens: [MixinTokenItem] = []
    private var hasAssetInLegacyNetwork = false
    
    private weak var walletSwitchBadgeView: BadgeDotView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = R.string.localizable.privacy_wallet()
        titleInfoStackView.setCustomSpacing(6, after: titleLabel)
        addIconIntoTitleView(image: R.image.privacy_wallet())
        
        tableHeaderView.actionView.actions = [.buy, .receive, .send, .swap]
        tableHeaderView.delegate = self
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
        
        if !BadgeManager.shared.hasViewed(identifier: .walletSwitch) {
            let badge = BadgeDotView()
            titleView.addSubview(badge)
            badge.snp.makeConstraints { make in
                make.centerY.equalTo(self.walletSwitchImageView.snp.centerY).offset(-8)
                make.leading.equalTo(self.walletSwitchImageView.snp.trailing).offset(-2)
            }
            walletSwitchBadgeView = badge
        }
        if !BadgeManager.shared.hasViewed(identifier: .buy) {
            tableHeaderView.actionView.badgeActions.insert(.buy)
        }
        if !BadgeManager.shared.hasViewed(identifier: .swap) {
            tableHeaderView.actionView.badgeActions.insert(.swap)
        }
        notificationCenter.addObserver(
            self,
            selector: #selector(hideBadgeViewIfMatches(_:)),
            name: BadgeManager.viewedNotification,
            object: nil
        )
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
            reporter.report(event: .allTransactions, tags: ["source": "wallet_home"])
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
    
    override func makeSearchViewController() -> UIViewController {
        let modelController = WalletSearchMixinTokenController()
        modelController.delegate = self
        let viewController = WalletSearchViewController(modelController: modelController)
        return viewController
    }
    
    @objc private func reloadData() {
        DispatchQueue.global().async { [weak self] in
            let tokens = TokenDAO.shared.notHiddenTokens(includesZeroBalanceItems: true)
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
                let myDeposits = DepositFilter.myDeposits(from: deposits)
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
    
    @objc private func hideBadgeViewIfMatches(_ notification: Notification) {
        guard let identifier = notification.userInfo?[BadgeManager.identifierUserInfoKey] as? BadgeManager.Identifier else {
            return
        }
        switch identifier {
        case .swap:
            tableHeaderView.actionView.badgeActions.remove(.swap)
        case .walletSwitch:
            walletSwitchBadgeView?.removeFromSuperview()
        case .buy:
            tableHeaderView.actionView.badgeActions.remove(.buy)
        default:
            break
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
                if let app = response.app, let container = UIApplication.homeContainerViewController {
                    container.presentWebViewController(context: .init(conversationId: conversationID, app: app))
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
        reporter.report(event: .assetDetail, tags: ["wallet": "main", "source": "wallet_home"])
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

extension PrivacyWalletViewController: WalletHeaderView.Delegate {
    
    func walletHeaderView(_ view: WalletHeaderView, didSelectAction action: TokenAction) {
        switch action {
        case .buy:
            let buy = BuyTokenInputAmountViewController(wallet: .privacy)
            tableHeaderView.actionView.badgeActions.remove(.buy)
            navigationController?.pushViewController(buy, animated: true)
            BadgeManager.shared.setHasViewed(identifier: .buy)
        case .send:
            reporter.report(event: .sendStart, tags: ["wallet": "main", "source": "wallet_home"])
            let selector = MixinTokenSelectorViewController(intent: .send)
            selector.onSelected = { (token, location) in
                reporter.report(event: .sendTokenSelect, tags: ["method": location.asEventMethod])
                let receiver = MixinTokenReceiverViewController(token: token)
                self.navigationController?.pushViewController(receiver, animated: true)
            }
            present(selector, animated: true, completion: nil)
        case .receive:
            reporter.report(event: .receiveStart, tags: ["wallet": "main", "source": "wallet_home"])
            let selector = MixinTokenSelectorViewController(intent: .receive)
            selector.searchFromRemote = true
            selector.onSelected = { (token, location) in
                reporter.report(event: .receiveTokenSelect, tags: ["method": location.asEventMethod])
                let deposit = DepositViewController(token: token)
                self.navigationController?.pushViewController(deposit, animated: true)
            }
            withMnemonicsBackupChecked {
                self.present(selector, animated: true, completion: nil)
            }
        case .swap:
            reporter.report(event: .tradeStart, tags: ["wallet": "main", "source": "wallet_home"])
            tableHeaderView.actionView.badgeActions.remove(.swap)
            let swap = MixinSwapViewController(sendAssetID: nil, receiveAssetID: nil, referral: nil)
            navigationController?.pushViewController(swap, animated: true)
            BadgeManager.shared.setHasViewed(identifier: .swap)
        }
    }
    
    func walletHeaderViewWantsToRevealPendingDeposits(_ view: WalletHeaderView) {
        let transactionHistory = MixinTransactionHistoryViewController(type: .pending)
        navigationController?.pushViewController(transactionHistory, animated: true)
        reporter.report(event: .allTransactions, tags: ["source": "wallet_home"])
    }
    
    func walletHeaderViewWantsToRevealWatchingAddresses(_ view: WalletHeaderView) {
        
    }
    
}

extension PrivacyWalletViewController: WalletSearchMixinTokenController.Delegate {
    
    func walletSearchMixinTokenController(_ controller: WalletSearchMixinTokenController, didSelectToken token: MixinTokenItem) {
        let controller = MixinTokenViewController(token: token)
        navigationController?.pushViewController(controller, animated: true)
        DispatchQueue.global().async {
            TokenDAO.shared.save(assets: [token])
        }
        reporter.report(event: .assetDetail, tags: ["wallet": "main", "source": "wallet_search"])
    }
    
    func walletSearchMixinTokenController(_ controller: WalletSearchMixinTokenController, didSelectTrendingItem item: AssetItem) {
        if let token = TokenDAO.shared.tokenItem(assetID: item.assetId) {
            walletSearchMixinTokenController(controller, didSelectToken: token)
        } else {
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            DispatchQueue.global().async { [weak self] in
                func report(error: Error) {
                    DispatchQueue.main.sync {
                        hud.set(style: .error, text: error.localizedDescription)
                        hud.scheduleAutoHidden()
                    }
                }
                
                let chainID = item.chainId
                let chain: Chain
                if let localChain = ChainDAO.shared.chain(chainId: chainID) {
                    chain = localChain
                } else {
                    switch NetworkAPI.chain(id: chainID) {
                    case .success(let remoteChain):
                        chain = remoteChain
                        ChainDAO.shared.save([chain])
                        Web3ChainDAO.shared.save([chain])
                    case .failure(let error):
                        report(error: error)
                        return
                    }
                }
                switch SafeAPI.assets(id: item.assetId) {
                case .success(let token):
                    let item = MixinTokenItem(token: token, balance: "0", isHidden: false, chain: chain)
                    DispatchQueue.main.sync {
                        hud.hide()
                        self?.walletSearchMixinTokenController(controller, didSelectToken: item)
                    }
                case .failure(let error):
                    report(error: error)
                }
            }
        }
    }
    
}
