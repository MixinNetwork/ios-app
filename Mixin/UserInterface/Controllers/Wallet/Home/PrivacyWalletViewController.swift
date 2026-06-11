import UIKit
import OrderedCollections
import MixinServices

final class PrivacyWalletViewController: WalletViewController {
    
    private var hasAssetInLegacyNetwork = false
    private var tokens: OrderedDictionary<String, MixinTokenItem> = [:]
    private var transactions: OrderedDictionary<String, SafeSnapshotItem> = [:]
    
    private var pendingDepositObserver: PrivacyWalletPendingDepositObserver?
    private var perpsPositionLoader: PerpetualPositionLoader?
    private var perpsTopMoverLoader: PerpetualMarketLoader?
    private var searchTokenHandler: WalletSearchMixinTokenHandler?
    
    private weak var walletSwitchBadgeView: BadgeDotView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = R.string.localizable.privacy_wallet()
        titleInfoStackView.setCustomSpacing(6, after: titleLabel)
        addIconIntoTitleView(image: R.image.privacy_wallet())
        if !BadgeManager.shared.hasViewed(identifier: .walletSwitch) {
            let badge = BadgeDotView()
            titleView.addSubview(badge)
            badge.snp.makeConstraints { make in
                make.centerY.equalTo(self.walletSwitchImageView.snp.centerY).offset(-8)
                make.leading.equalTo(self.walletSwitchImageView.snp.trailing).offset(-2)
            }
            walletSwitchBadgeView = badge
        }
        
        overviewAction = .general
        self.walletActionHandler = PrivacyWalletOverviewActionHandler(
            tradeSource: .walletHome,
            responder: self
        )
        let pendingDepositObserver = PrivacyWalletPendingDepositObserver()
        pendingDepositObserver.delegate = self
        pendingDepositObserver.reloadPendingDeposits()
        self.pendingDepositObserver = pendingDepositObserver
        collectionView.delegate = self
        
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
            selector: #selector(reloadPerpsPositions),
            name: PerpsPositionDAO.perpsPositionDidChangeNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadPerpsTopMovers),
            name: PerpsMarketDAO.marketsDidUpdateNotification,
            object: nil
        )
        reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global().async {
            let hasAssetInLegacyNetwork = AssetDAO.shared.hasPositiveBalancedAssets()
            DispatchQueue.main.async {
                self.hasAssetInLegacyNetwork = hasAssetInLegacyNetwork
            }
        }
        pendingDepositObserver?.reloadPendingDeposits()
        perpsPositionLoader?.start()
        perpsTopMoverLoader?.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        perpsPositionLoader?.stop()
        perpsTopMoverLoader?.stop()
    }
    
    override func switchFromWallets(_ sender: Any) {
        walletSwitchBadgeView?.removeFromSuperview()
        super.switchFromWallets(sender)
    }
    
    override func searchAction(_ sender: Any) {
        let modelController = WalletSearchMixinTokenController()
        let searchTokenHandler = WalletSearchMixinTokenHandler(
            navigationController: navigationController
        )
        modelController.delegate = searchTokenHandler
        let search = WalletSearchViewController(modelController: modelController)
        search.presentAsChild(on: self)
        self.searchTokenHandler = searchTokenHandler
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
    
    override func configure(tokenCell: TokenCell, withTokenOf assetID: String) {
        guard let token = tokens[assetID] else {
            return
        }
        tokenCell.load(token: token)
    }
    
    override func configure(transactionCell: TransactionCell, withTransactionOf id: String) {
        guard let snapshot = transactions[id] else {
            return
        }
        transactionCell.load(snapshot: snapshot)
    }
    
    override func hideTokenAction(indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(
            style: .destructive,
            title: R.string.localizable.hide()
        ) { [weak self] (action, _, completionHandler) in
            guard
                let self,
                let item = self.dataSource.itemIdentifier(for: indexPath),
                case let .token(assetID) = item,
                let token = self.tokens[assetID]
            else {
                return
            }
            let alert = UIAlertController(title: R.string.localizable.wallet_hide_asset_confirmation(token.symbol), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: R.string.localizable.hide(), style: .default, handler: { (_) in
                self.hide(token: token)
            }))
            self.present(alert, animated: true, completion: nil)
            completionHandler(true)
        }
        action.backgroundColor = R.color.theme()
        return UISwipeActionsConfiguration(actions: [action])
    }
    
    override func viewAllTokens() {
        let tokens = MixinTokensViewController()
        navigationController?.pushViewController(tokens, animated: true)
    }
    
    override func viewAllTransactions() {
        let transactionHistory = MixinTransactionHistoryViewController(type: nil)
        navigationController?.pushViewController(transactionHistory, animated: true)
        reporter.report(event: .allTransactions, tags: ["source": "wallet_home"])
    }
    
    override func viewPerpsPositions() {
        let positions = PerpetualPositionsViewController(wallet: .privacy)
        navigationController?.pushViewController(positions, animated: true)
    }
    
    override func viewPerps() {
        UserOperationAnalytics.tradeSource = .walletHome
        let trade = TradeViewController(
            wallet: .privacy,
            trading: .perpetualFutures,
            sendAssetID: nil,
            receiveAssetID: nil,
            referral: nil
        )
        guard let trade else {
            return
        }
        withAccountRecoveryChecked { [weak self] in
            self?.navigationController?.pushViewController(trade, animated: true)
        }
    }
    
    @objc private func reloadData() {
        let displayItemsCount = itemsCount
        let hasMoreDeterminatingItemsCount = itemsCount + 1
        DispatchQueue.global().async { [weak self, perpsTopMoversCount] in
            var snapshot = DataSourceSnapshot()
            
            let tokensValue = TokenDAO.shared.usdBalanceSum(includesHiddenTokens: false)
            let formattedTokensValue = CurrencyFormatter.localizedString(
                from: tokensValue * Currency.current.decimalRate,
                format: .fiatMoneyPrecision,
                sign: .never,
                symbol: .currencySymbol
            )
            let perpsValue = PerpsPositionDAO.shared.positionValue()
            let btcPrice = TokenDAO.shared.usdPrice(assetID: AssetID.btc)
            let overview = WalletOverview(
                tokensValue: tokensValue,
                perpsValue: perpsValue.decimalValue,
                btcPrice: btcPrice
            )
            
            let tokens = TokenDAO.shared.notHiddenTokens(
                includesZeroBalanceItems: true,
                limit: hasMoreDeterminatingItemsCount,
            )
            let hasMoreToken = tokens.count > displayItemsCount
            let hasPositiveBalanceToken = tokens.contains { item in
                item.decimalBalance > 0
            }
            let displayTokens = tokens
                .prefix(displayItemsCount)
                .reduce(into: OrderedDictionary()) { result, item in
                    result[item.assetID] = item
                }
            
            let transactions = SafeSnapshotDAO.shared.snapshots(
                filter: .init(),
                order: .newest,
                limit: hasMoreDeterminatingItemsCount
            )
            let displayTransactions = transactions
                .prefix(displayItemsCount)
                .reduce(into: OrderedDictionary()) { result, item in
                    result[item.id] = item
                }
            let hasTransaction = !transactions.isEmpty
            let hasMoreTransactions = transactions.count > displayItemsCount
            
            let perpsPositions = PerpsPositionDAO.shared.positionItems()
            let hasMorePerpsPositions = perpsPositions.count > displayItemsCount
            let displayPerpsPositions = perpsPositions
                .prefix(displayItemsCount)
                .reduce(into: OrderedDictionary()) { result, position in
                    result[position.positionID] = PerpetualPositionViewModel(
                        wallet: .privacy,
                        position: position
                    )
                }
            let perpsTopMovers: OrderedDictionary<String, PerpetualMarketViewModel>
            if hasPositiveBalanceToken || hasTransaction {
                snapshot.appendSections([.overview])
                snapshot.appendItems([.overview], toSection: .overview)
            } else {
                snapshot.appendSections([.emptyWalletInstruction])
                snapshot.appendItems([.emptyWalletInstruction], toSection: .emptyWalletInstruction)
            }
            if perpsPositions.isEmpty {
                perpsTopMovers = PerpsMarketDAO.shared.availableTopMovers(
                    count: perpsTopMoversCount
                ).reduce(into: OrderedDictionary()) { result, market in
                    result[market.marketID] = PerpetualMarketViewModel(market: market)
                }
            } else {
                perpsTopMovers = [:]
                snapshot.appendSections([.perpsPositions])
                snapshot.appendItems(
                    displayPerpsPositions.values.map({ Item.perpsPosition(positionID: $0.positionID) }),
                    toSection: .perpsPositions
                )
            }
            if !tokens.isEmpty {
                snapshot.appendSections([.tokens])
                snapshot.appendItems(
                    displayTokens.values.map({ Item.token(assetID: $0.assetID) }),
                    toSection: .tokens
                )
            }
            if hasTransaction {
                snapshot.appendSections([.transactions])
                snapshot.appendItems(
                    displayTransactions.values.map({ Item.transaction(id: $0.id) }),
                    toSection: .transactions
                )
            }
            if !perpsTopMovers.isEmpty {
                snapshot.appendSections([.perpsTopMovers])
                snapshot.appendItems(
                    perpsTopMovers.values.map({ Item.perpsTopMover(marketID: $0.market.marketID) }),
                    toSection: .perpsTopMovers
                )
            }
            
            snapshot.appendSections([.support, .benefit])
            snapshot.appendItems(
                [.support(.contactUs), .support(.helpCenter)],
                toSection: .support
            )
            snapshot.appendItems(
                [.benefit(.privacyWallet)],
                toSection: .benefit
            )
            
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.overview = overview
                
                self.tokens = displayTokens
                self.tokensValue = formattedTokensValue
                self.hasMoreTokens = hasMoreToken
                
                self.transactions = displayTransactions
                self.hasMoreTransactions = hasMoreTransactions
                
                self.perpsValue = perpsValue
                self.perpsPositions = displayPerpsPositions
                self.hasMorePerpsPositions = hasMorePerpsPositions
                self.perpsTopMovers = perpsTopMovers
                
                self.insertTipsReferralSection(into: &snapshot)
                self.dataSource.applySnapshotUsingReloadData(snapshot)
                
                if !perpsPositions.isEmpty {
                    let positionLoader: PerpetualPositionLoader
                    if let loader = self.perpsPositionLoader {
                        positionLoader = loader
                    } else {
                        positionLoader = PerpetualPositionLoader(walletID: Wallet.privacy.tradingWalletID)
                        self.perpsPositionLoader = positionLoader
                    }
                    if self.isViewAppearing {
                        positionLoader.start()
                    }
                    self.perpsTopMoverLoader?.stop()
                    self.perpsTopMoverLoader = nil
                } else if !perpsTopMovers.isEmpty {
                    let topMoverLoader: PerpetualMarketLoader
                    if let loader = self.perpsTopMoverLoader {
                        topMoverLoader = loader
                    } else {
                        topMoverLoader = PerpetualMarketLoader(marketID: nil)
                        self.perpsTopMoverLoader = topMoverLoader
                    }
                    if self.isViewAppearing {
                        topMoverLoader.start()
                    }
                    self.perpsPositionLoader?.stop()
                    self.perpsPositionLoader = nil
                } else {
                    self.perpsPositionLoader?.stop()
                    self.perpsPositionLoader = nil
                    self.perpsTopMoverLoader?.stop()
                    self.perpsTopMoverLoader = nil
                }
            }
        }
    }
    
    @objc private func reloadPerpsPositions() {
        let snapshot = dataSource.snapshot()
        guard snapshot.sectionIdentifiers.contains(.perpsPositions) else {
            // New position incoming
            reloadData()
            return
        }
        let displayItemsCount = itemsCount
        DispatchQueue.global().async { [weak self] in
            let perpsPositions = PerpsPositionDAO.shared.positionItems()
            guard !perpsPositions.isEmpty else {
                DispatchQueue.main.async {
                    self?.reloadData()
                }
                return
            }
            let perpsValue = PerpsPositionDAO.shared.positionValue()            
            let hasMorePerpsPositions = perpsPositions.count > displayItemsCount
            let displayPerpsPositions = perpsPositions
                .prefix(displayItemsCount)
                .reduce(into: OrderedDictionary()) { result, position in
                    result[position.positionID] = PerpetualPositionViewModel(
                        wallet: .privacy,
                        position: position
                    )
                }
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                var snapshot = self.dataSource.snapshot()
                if snapshot.sectionIdentifiers.contains(.perpsPositions) {
                    self.overview?.update(perpsValue: perpsValue.decimalValue)
                    self.perpsValue = perpsValue
                    self.perpsPositions = displayPerpsPositions
                    self.hasMorePerpsPositions = hasMorePerpsPositions
                    if snapshot.sectionIdentifiers.contains(.overview) {
                        snapshot.reconfigureItems([.overview])
                    }
                    snapshot.deleteItems(
                        snapshot.itemIdentifiers(inSection: .perpsPositions)
                    )
                    let newItems = displayPerpsPositions.values.map { position in
                        Item.perpsPosition(positionID: position.positionID)
                    }
                    snapshot.appendItems(newItems, toSection: .perpsPositions)
                    snapshot.reloadItems(newItems)
                    snapshot.reloadSections([.perpsPositions])
                    self.dataSource.apply(snapshot, animatingDifferences: false)
                } else {
                    self.reloadData()
                }
            }
        }
    }
    
    @objc private func reloadPerpsTopMovers() {
        let snapshot = dataSource.snapshot()
        guard snapshot.sectionIdentifiers.contains(.perpsTopMovers) else {
            return
        }
        DispatchQueue.global().async { [perpsTopMoversCount, weak self] in
            let perpsTopMovers = PerpsMarketDAO.shared.availableTopMovers(
                count: perpsTopMoversCount
            ).reduce(into: OrderedDictionary()) { result, market in
                result[market.marketID] = PerpetualMarketViewModel(market: market)
            }
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                var snapshot = self.dataSource.snapshot()
                guard snapshot.sectionIdentifiers.contains(.perpsTopMovers) else {
                    return
                }
                self.perpsTopMovers = perpsTopMovers
                snapshot.deleteItems(
                    snapshot.itemIdentifiers(inSection: .perpsTopMovers)
                )
                let newItems = perpsTopMovers.values.map { topMover in
                    Item.perpsTopMover(marketID: topMover.market.marketID)
                }
                snapshot.appendItems(newItems, toSection: .perpsTopMovers)
                snapshot.reconfigureItems(newItems)
                self.dataSource.apply(snapshot, animatingDifferences: false)
            }
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
    
    private func hide(token: MixinTokenItem) {
        DispatchQueue.global().async { [weak self] in
            let extra = TokenExtra(
                assetID: token.assetID,
                kernelAssetID: token.kernelAssetID,
                isHidden: true,
                balance: token.balance,
                updatedAt: Date().toUTCString()
            )
            TokenExtraDAO.shared.insertOrUpdateHidden(extra: extra)
            DispatchQueue.main.async {
                self?.reloadData()
            }
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

extension PrivacyWalletViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        switch item {
        case .overview, .emptyWalletInstruction, .tip, .referral, .benefit:
            break
        case .perpsPosition(let positionID):
            if let position = perpsPositions[positionID],
               let market = PerpsMarketDAO.shared.market(marketID: position.marketID),
               let viewModel = PerpetualMarketViewModel(market: market)
            {
                let market = PerpetualMarketViewController(
                    wallet: .privacy,
                    viewModel: viewModel,
                )
                navigationController?.pushViewController(market, animated: true)
            }
        case .token(let assetID):
            if let token = tokens[assetID] {
                let viewController = MixinTokenViewController(token: token)
                navigationController?.pushViewController(viewController, animated: true)
                reporter.report(event: .assetDetail, tags: ["wallet": "main", "source": "wallet_home"])
            }
        case .transaction(let id):
            if let transaction = transactions[id],
               let viewController = SafeSnapshotViewController(snapshot: transaction)
            {
                navigationController?.pushViewController(viewController, animated: true)
                reporter.report(event: .transactionDetail, tags: ["source": "wallet_home"])
            }
        case .perpsTopMover(let marketID):
            if let viewModel = perpsTopMovers[marketID] {
                let market = PerpetualMarketViewController(
                    wallet: .privacy,
                    viewModel: viewModel,
                )
                navigationController?.pushViewController(market, animated: true)
            }
        case .support(let support):
            request(support: support)
        }
    }
    
}

extension PrivacyWalletViewController: PrivacyWalletPendingDepositObserver.Delegate {
    
    func privacyWalletPendingDepositObserver(
        _ observer: PrivacyWalletPendingDepositObserver,
        didUpdateWith tokens: [MixinToken],
        snapshots: [SafeSnapshot]
    ) {
        if snapshots.isEmpty {
            overviewTray = nil
        } else {
            overviewTray = .pendingDeposits(tokens: tokens, snapshots: snapshots)
        }
        var snapshot = dataSource.snapshot()
        if snapshot.itemIdentifiers.contains(.overview) {
            snapshot.reconfigureItems([.overview])
            dataSource.apply(snapshot, animatingDifferences: false)
        } else {
            reloadData()
        }
    }
    
}

extension PrivacyWalletViewController: TransactionCell.Delegate {
    
    func transactionCellDidSelectIcon(_ cell: TransactionCell) {
        guard
            let indexPath = collectionView.indexPath(for: cell),
            let item = dataSource.itemIdentifier(for: indexPath),
            case let .transaction(id) = item,
            let userID = transactions[id]?.opponentUserID,
            let user = UserDAO.shared.getUser(userId: userID)
        else {
            return
        }
        let profile = UserProfileViewController(user: user)
        present(profile, animated: true, completion: nil)
    }
    
}
