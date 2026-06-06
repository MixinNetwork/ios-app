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
            selector: #selector(reloadData),
            name: PerpsPositionDAO.perpsPositionDidChangeNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadData),
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
        DispatchQueue.global().async { [weak self, itemsCount, perpsTopMoversCount] in
            var snapshot = DataSourceSnapshot()
            
            let perpsValue = PerpsPositionDAO.shared.positionValue()
            let overview = {
                let usdValue = TokenDAO.shared.usdBalanceSum(includesHiddenTokens: false) + perpsValue.decimalValue
                let btcPrice: Decimal?
                if let price = TokenDAO.shared.usdPrice(assetID: AssetID.btc) {
                    btcPrice = Decimal(string: price, locale: .enUSPOSIX)
                } else {
                    btcPrice = nil
                }
                return WalletOverview(usdValue: usdValue, btcPrice: btcPrice)
            }()
            
            let tokens = TokenDAO.shared.notHiddenTokens(
                includesZeroBalanceItems: true,
                limit: itemsCount
            ).reduce(into: OrderedDictionary()) { result, item in
                result[item.assetID] = item
            }
            let hasPositiveBalanceToken = tokens.values.contains { item in
                item.decimalBalance > 0
            }
            let transactions = SafeSnapshotDAO.shared.snapshots(
                filter: .init(),
                order: .newest,
                limit: itemsCount
            ).reduce(into: OrderedDictionary()) { result, item in
                result[item.id] = item
            }
            let hasTransaction = !transactions.isEmpty
            let perpsPositions = PerpsPositionDAO.shared.positionItems()
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
                snapshot.appendSections([.perpPositions])
                snapshot.appendItems(
                    perpsPositions.values.map({ Item.perpsPosition(positionID: $0.positionID) }),
                    toSection: .perpPositions
                )
            }
            if !tokens.isEmpty {
                snapshot.appendSections([.tokens])
                snapshot.appendItems(
                    tokens.values.map({ Item.token(assetID: $0.assetID) }),
                    toSection: .tokens
                )
            }
            if hasTransaction {
                snapshot.appendSections([.transactions])
                snapshot.appendItems(
                    transactions.values.map({ Item.transaction(id: $0.id) }),
                    toSection: .transactions
                )
            }
            if !perpsTopMovers.isEmpty {
                snapshot.appendSections([.perpsTopMovers])
                snapshot.appendItems(
                    perpsTopMovers.values.map({ Item.perpsTopMovers(marketID: $0.market.marketID) }),
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
                self.tokens = tokens
                self.transactions = transactions
                self.perpsValue = perpsValue
                self.perpsPositions = perpsPositions
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
        case .perpsTopMovers(let marketID):
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
        overviewTray = .pendingDeposits(tokens: tokens, snapshots: snapshots)
        reconfigureIfExists(item: .overview)
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
