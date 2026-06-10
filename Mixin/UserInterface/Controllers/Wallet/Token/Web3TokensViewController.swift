import UIKit
import MixinServices

final class Web3TokensViewController: TokensViewController {
    
    private let wallet: Web3Wallet
    
    private var secret: CommonWalletSecret?
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
        Web3Wallet.Availability(wallet: wallet, secret: secret)
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
            title: R.string.localizable.wallet_home_tokens(),
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
            selector: #selector(reloadPendingTransactions),
            name: Web3TransactionDAO.transactionDidUpdateNotification,
            object: nil
        )
        reloadData()
        
        let pendingTransactionLoader = CommonWalletPendingTransactionLoader(
            walletID: wallet.walletID
        )
        self.pendingTransactionObserver = pendingTransactionLoader
        reloadPendingTransactions()
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
            let secret: CommonWalletSecret?
            let action: WalletOverview.Action?
            let watchingAddresses: WatchingAddresses?
            switch wallet.category.knownCase {
            case .classic:
                secret = nil
                action = .general
                watchingAddresses = nil
            case .importedMnemonic:
                if let mnemonics = AppGroupKeychain.importedMnemonics(walletID: walletID) {
                    secret = .mnemonics(mnemonics)
                } else {
                    secret = nil
                }
                action = secret == nil ? .importSecret(.importMnemonics) : .general
                watchingAddresses = nil
            case .importedPrivateKey:
                if let privateKey = AppGroupKeychain.importedPrivateKey(walletID: walletID) {
                    let kind: Web3Chain.Kind? = .singleKindWallet(chainIDs: chainIDs)
                    switch kind {
                    case .bitcoin:
                        secret = .privateKey(privateKey, .bitcoin)
                    case .evm:
                        secret = .privateKey(privateKey, .evm)
                    case .solana:
                        secret = .privateKey(privateKey, .solana)
                    case .none:
                        secret = nil
                    }
                } else {
                    secret = nil
                }
                action = secret == nil ? .importSecret(.importPrivateKey) : .general
                watchingAddresses = nil
            case .watchAddress, .none:
                secret = nil
                action = nil
                watchingAddresses = WatchingAddresses(addresses: addresses)
            }
            let tray: WalletOverview.Tray?
            if let watchingAddresses {
                let description = R.string.localizable.you_are_watching_address(
                    watchingAddresses.prettyFormatted
                )
                tray = .watching(description: description)
            } else {
                tray = nil
            }
            
            let overview: WalletOverview = {
                let usdValue = Web3TokenDAO.shared.notHiddenUSDBalanceSum(walletID: walletID)
                let btcPrice: Decimal?
                if let price = TokenDAO.shared.usdPrice(assetID: AssetID.btc) {
                    btcPrice = Decimal(string: price, locale: .enUSPOSIX)
                } else {
                    btcPrice = nil
                }
                return WalletOverview(usdValue: usdValue, btcPrice: btcPrice)
            }()
            let tokens = Web3TokenDAO.shared.notHiddenTokens(
                walletID: walletID,
                includesZeroBalanceItems: true,
                limit: nil,
            )
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.overview = overview
                self.overviewAction = action
                self.overviewTray = tray
                self.secret = secret
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
    
    @objc private func reloadPendingTransactions() {
        let walletID = wallet.walletID
        DispatchQueue.global().async { [weak self] in
            let transactions = Web3TransactionDAO.shared.pendingTransactions(walletID: walletID)
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.overviewTray = .pendingTransactions(transactions)
                let overview = IndexSet(integer: Section.overview.rawValue)
                self.collectionView.reloadSections(overview)
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
        Section.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .overview:
            1
        case .tokens:
            tokens?.count ?? 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section)! {
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

extension Web3TokensViewController: PrivacyWalletPendingDepositObserver.Delegate {
    
    func privacyWalletPendingDepositObserver(
        _ observer: PrivacyWalletPendingDepositObserver,
        didUpdateWith tokens: [MixinToken],
        snapshots: [SafeSnapshot]
    ) {
        overviewTray = .pendingDeposits(tokens: tokens, snapshots: snapshots)
        let overviewIndexPath = IndexPath(item: 0, section: Section.overview.rawValue)
        if let cell = collectionView.cellForItem(at: overviewIndexPath) as? WalletOverviewCell {
            cell.load(tray: overviewTray)
        }
    }
    
}
