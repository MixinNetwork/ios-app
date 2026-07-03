import UIKit
import MixinServices

final class Web3TokensViewController: TokensViewController {
    
    private let wallet: Web3Wallet
    
    private var importedSecret: CommonWalletImportedSecret?
    private var supportedChainIDs: Set<String> = []
    private var overview: WalletOverview?
    private var overviewAction: WalletOverview.Action?
    private var overviewTray: WalletOverview.Tray?
    private var watchingAddresses: WatchingAddresses?
    private var tokens: [Web3TokenItem]?
    
    private var isDisplayingSearch = false
    private var searchTokenHandler: WalletSearchWeb3TokenHandler?
    private var overviewActionHandler: CommonWalletOverviewActionHandler?
    private var pendingTransactionObserver: CommonWalletPendingTransactionLoader?
    
    private var availability: Web3Wallet.Availability {
        Web3Wallet.Availability(
            wallet: wallet,
            importedSecret: importedSecret,
            supportedChainIDs: supportedChainIDs
        )
    }
    
    init(wallet: Web3Wallet) {
        self.wallet = wallet
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.titleView = WalletIdentifyingNavigationTitleView(
            title: R.string.localizable.assets(),
            wallet: .common(wallet)
        )
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                image: R.image.ic_title_more(),
                style: .plain,
                target: self,
                action: #selector(presentMoreMenu(_:))
            ),
            UIBarButtonItem(
                image: R.image.ic_title_search(),
                style: .plain,
                target: self,
                action: #selector(presentSearch(_:))
            ),
        ]
        collectionView.dataSource = self
        collectionView.delegate = self
        
        let notificationCenter: NotificationCenter = .default
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadDataIfWalletMatch(_:)),
            name: Web3TokenDAO.tokensDidChangeNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadData),
            name: Web3TokenExtraDAO.tokenVisibilityDidChangeNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadTokensFromRemote),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadData),
            name: Web3TransactionDAO.transactionDidUpdateNotification,
            object: nil
        )
        
        let pendingTransactionLoader = CommonWalletPendingTransactionLoader(
            walletID: wallet.walletID
        )
        self.pendingTransactionObserver = pendingTransactionLoader
        
        reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadTokensFromRemote()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        pendingTransactionObserver?.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pendingTransactionObserver?.stop()
    }
    
    override func hideTokenAction(indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(
            style: .destructive,
            title: R.string.localizable.hide()
        ) { [weak self] (action, _, completionHandler) in
            guard
                let self,
                let token = self.tokens?[indexPath.item]
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
    
    @objc private func reloadTokensFromRemote() {
        let jobs = [
            RefreshWeb3WalletTokenJob(walletID: wallet.walletID),
            SyncWeb3TransactionJob(walletID: wallet.walletID),
        ]
        for job in jobs {
            ConcurrentJobQueue.shared.addJob(job: job)
        }
    }
    
    @objc private func reloadDataIfWalletMatch(_ notification: Notification) {
        guard let id = notification.userInfo?[Web3TokenDAO.walletIDUserInfoKey] as? String else {
            return
        }
        guard id == wallet.walletID else {
            return
        }
        reloadData()
    }
    
    @objc private func reloadData() {
        DispatchQueue.global().async { [weak self, wallet] in
            let walletID = wallet.walletID
            let addresses = Web3AddressDAO.shared.addresses(walletID: walletID)
            let chainIDs = Set(addresses.map(\.chainID))
            let importedSecret: CommonWalletImportedSecret?
            let action: WalletOverview.Action?
            let watchingAddresses: WatchingAddresses?
            switch wallet.category.knownCase {
            case .classic:
                importedSecret = nil
                action = .general
                watchingAddresses = nil
            case .importedMnemonic:
                if let mnemonics = AppGroupKeychain.importedMnemonics(walletID: walletID) {
                    importedSecret = .mnemonics(mnemonics)
                } else {
                    importedSecret = nil
                }
                action = importedSecret == nil ? .importSecret(.importMnemonics) : .general
                watchingAddresses = nil
            case .importedPrivateKey:
                if let privateKey = AppGroupKeychain.importedPrivateKey(walletID: walletID) {
                    let kind: Web3Chain.Kind? = .singleKindWallet(chainIDs: chainIDs)
                    switch kind {
                    case .bitcoin:
                        importedSecret = .privateKey(privateKey, .bitcoin)
                    case .evm:
                        importedSecret = .privateKey(privateKey, .evm)
                    case .solana:
                        importedSecret = .privateKey(privateKey, .solana)
                    case .none:
                        importedSecret = nil
                    }
                } else {
                    importedSecret = nil
                }
                action = importedSecret == nil ? .importSecret(.importPrivateKey) : .general
                watchingAddresses = nil
            case .watchAddress, .none:
                importedSecret = nil
                action = nil
                watchingAddresses = WatchingAddresses(addresses: addresses)
            }
            
            let tray: WalletOverview.Tray?
            let pendingTransactions = Web3TransactionDAO.shared.pendingTransactions(walletID: walletID)
            if let watchingAddresses {
                let description = R.string.localizable.you_are_watching_address(
                    watchingAddresses.prettyFormatted
                )
                tray = .watching(description: description)
            } else if !pendingTransactions.isEmpty {
                tray = .pendingTransactions(pendingTransactions)
            } else {
                tray = nil
            }
            
            let tokensValue = Web3TokenDAO.shared.notHiddenUSDBalanceSum(walletID: walletID)
            let btcPrice = TokenDAO.shared.usdPrice(assetID: AssetID.btc)
            let overview = WalletOverview(
                tokensValue: tokensValue,
                perpsValue: 0,
                cashValue: 0,
                btcPrice: btcPrice
            )
            let tokens = Web3TokenDAO.shared.notHiddenTokens(
                walletID: walletID,
                includesZeroBalanceItems: true,
                limit: nil,
            )
            var sections: [Section] = [.overview]
            if tokens.isEmpty {
                sections.append(.emptyIndicator)
            } else {
                sections.append(.tokens)
            }
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.sections = sections
                self.overview = overview
                self.overviewAction = action
                self.overviewTray = tray
                self.importedSecret = importedSecret
                self.supportedChainIDs = chainIDs
                self.tokens = tokens
                self.watchingAddresses = watchingAddresses
                self.overviewActionHandler = CommonWalletOverviewActionHandler(
                    wallet: wallet,
                    supportedChainIDs: chainIDs,
                    watchingAddresses: watchingAddresses,
                    tradeSource: .tokenList,
                    responder: self
                )
                self.collectionView.reloadData()
            }
        }
    }
    
    @objc private func presentSearch(_ sender: Any) {
        let modelController = WalletSearchWeb3TokenController(
            walletID: wallet.walletID,
            supportedChainIDs: supportedChainIDs
        )
        let searchTokenHandler = WalletSearchWeb3TokenHandler(
            wallet: wallet,
            availability: availability,
            navigationController: navigationController
        )
        modelController.delegate = searchTokenHandler
        let search = WalletSearchViewController(modelController: modelController)
        self.searchTokenHandler = searchTokenHandler
        self.isDisplayingSearch = true
        search.onWillDismiss = { [weak self] in
            self?.isDisplayingSearch = false
        }
        search.presentAsChild(on: self)
    }
    
    @objc private func presentMoreMenu(_ sender: Any) {
        let wallet = self.wallet
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: R.string.localizable.all_transactions(), style: .default, handler: { (_) in
            let history = Web3TransactionHistoryViewController(wallet: wallet, type: nil)
            self.navigationController?.pushViewController(history, animated: true)
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.hidden_assets(), style: .default, handler: { (_) in
            let hidden = HiddenWeb3TokensViewController(wallet: wallet, availability: self.availability)
            self.navigationController?.pushViewController(hidden, animated: true)
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
    }
    
    private func hide(token: Web3TokenItem) {
        DispatchQueue.global().async {
            reporter.report(event: .hideAsset, tags: ["wallet": "web3", "source": "token_list"])
            Web3TokenExtraDAO.shared.hide(walletID: token.walletID, assetID: token.assetID)
        }
    }
    
}

extension Web3TokensViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        isDisplayingSearch ? .hide : .secondaryBackground
    }
    
}

extension Web3TokensViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch sections[section] {
        case .overview:
            1
        case .tokens:
            tokens?.count ?? 0
        case .emptyIndicator:
            1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch sections[indexPath.section] {
        case .overview:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.wallet_overview, for: indexPath)!
            cell.load(overview: overview)
            cell.load(action: .general)
            cell.load(tray: overviewTray)
            cell.delegate = overviewActionHandler
            return cell
        case .tokens:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.token, for: indexPath)!
            if let token = tokens?[indexPath.item] {
                cell.load(web3Token: token)
            }
            return cell
        case .emptyIndicator:
            return collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.no_token_indicator, for: indexPath)!
        }
    }
    
}

extension Web3TokensViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let token = tokens?[indexPath.item] else {
            return
        }
        let viewController = Web3TokenViewController(
            wallet: wallet,
            token: token,
            availability: availability
        )
        navigationController?.pushViewController(viewController, animated: true)
    }
    
}
