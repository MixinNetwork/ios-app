import UIKit
import OrderedCollections
import MixinServices

final class CommonWalletViewController: WalletViewController {
    
    private let maxNameUTF8Count = 32
    
    private var wallet: Web3Wallet
    private var secret: CommonWalletSecret?
    private var supportedChainIDs: Set<String> = []
    private var tokens: OrderedDictionary<String, Web3TokenItem> = [:]
    private var transactions: OrderedDictionary<String, Web3Transaction> = [:]
    private var transactionTokenSymbols: [String: String] = [:]
    private var legacyRenaming: WalletDigest.LegacyClassicWalletRenaming?
    private var pendingTransactionObserver: CommonWalletPendingTransactionLoader?
    private var searchTokenHandler: WalletSearchWeb3TokenHandler?
    
    private weak var renamingInputController: UIAlertController?
    
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
        
        titleLabel.text = ""
        switch wallet.category.knownCase {
        case .classic, .importedMnemonic, .importedPrivateKey, .none:
            break
        case .watchAddress:
            addIconIntoTitleView(image: R.image.watching_wallet())
        }
        
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
        
        collectionView.delegate = self
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
    
    override func searchAction(_ sender: Any) {
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
        search.presentAsChild(on: self)
        self.searchTokenHandler = searchTokenHandler
    }
    
    override func moreAction(_ sender: Any) {
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
        switch legacyRenaming {
        case .none, .required:
            break
        case .notInvolved, .done:
            sheet.addAction(UIAlertAction(title: R.string.localizable.rename_wallet(), style: .default, handler: { (_) in
                self.inputNewWalletName()
            }))
        }
        switch wallet.category.knownCase {
        case .classic, .none:
            break
        case .importedMnemonic:
            switch secret {
            case .mnemonics(let mnemonics):
                sheet.addAction(UIAlertAction(title: R.string.localizable.show_mnemonic_phrase(), style: .default, handler: { (_) in
                    let introduction = AddWalletIntroductionViewController(
                        action: .exportSecret(.mnemonics(mnemonics))
                    )
                    self.navigationController?.pushViewController(introduction, animated: true)
                }))
                sheet.addAction(UIAlertAction(title: R.string.localizable.show_private_key(), style: .default, handler: { (_) in
                    let introduction = ExportPrivateKeyNetworkSelectorViewController(wallet: wallet, mnemonics: mnemonics)
                    self.present(introduction, animated: true)
                }))
            default:
                break
            }
            sheet.addAction(UIAlertAction(title: R.string.localizable.delete_wallet(), style: .destructive, handler: { (_) in
                self.deleteWallet()
            }))
        case .importedPrivateKey:
            switch secret {
            case let .privateKey(privateKey, kind):
                sheet.addAction(UIAlertAction(title: R.string.localizable.show_private_key(), style: .default, handler: { (_) in
                    let introduction = AddWalletIntroductionViewController(
                        action: .exportSecret(.privateKey(privateKey, kind))
                    )
                    self.navigationController?.pushViewController(introduction, animated: true)
                }))
            default:
                break
            }
            sheet.addAction(UIAlertAction(title: R.string.localizable.delete_wallet(), style: .destructive, handler: { (_) in
                self.deleteWallet()
            }))
        case .watchAddress:
            sheet.addAction(UIAlertAction(title: R.string.localizable.delete_wallet(), style: .destructive, handler: { (_) in
                self.deleteWallet()
            }))
        }
        sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
    }
    
    override func configure(tokenCell: TokenCell, withTokenOf assetID: String) {
        guard let token = tokens[assetID] else {
            return
        }
        tokenCell.load(web3Token: token)
    }
    
    override func configure(transactionCell: TransactionCell, withTransactionOf id: String) {
        guard let transaction = transactions[id] else {
            return
        }
        transactionCell.load(transaction: transaction, symbols: transactionTokenSymbols)
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
        let tokens = Web3TokensViewController(wallet: wallet)
        navigationController?.pushViewController(tokens, animated: true)
    }
    
    override func viewAllTransactions() {
        let history = Web3TransactionHistoryViewController(wallet: wallet, type: nil)
        self.navigationController?.pushViewController(history, animated: true)
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
        let displayItemsCount = itemsCount
        let hasMoreDeterminatingItemsCount = itemsCount + 1
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
            
            var snapshot = DataSourceSnapshot()
            
            let tokens = Web3TokenDAO.shared.notHiddenTokens(
                walletID: walletID,
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
            
            let transactions = Web3TransactionDAO.shared.transactions(
                walletID: walletID,
                filter: .init(),
                order: .newest,
                limit: hasMoreDeterminatingItemsCount,
            )
            let hasTransaction = !transactions.isEmpty
            let hasMoreTransactions = transactions.count > displayItemsCount
            let displayTransactions = transactions
                .prefix(displayItemsCount)
                .reduce(into: OrderedDictionary()) { result, item in
                    result[item.transactionHash] = item
                }
            var assetIDs: Set<String> = []
            for tx in displayTransactions.values {
                assetIDs.formUnion(tx.allAssetIDs)
            }
            let tokenSymbols = Web3TokenDAO.shared.tokenSymbols(ids: assetIDs)
                .mapValues { symbol in
                    TextTruncation.truncateTail(string: symbol, prefixCount: 8)
                }
            
            let tokensValue = Web3TokenDAO.shared.notHiddenUSDBalanceSum(walletID: walletID)
            let formattedTokensValue = CurrencyFormatter.localizedString(
                from: tokensValue * Currency.current.decimalRate,
                format: .fiatMoneyPrecision,
                sign: .never,
                symbol: .currencySymbol
            )
            let overview: WalletOverview = {
                let btcPrice: Decimal?
                if let price = TokenDAO.shared.usdPrice(assetID: AssetID.btc) {
                    btcPrice = Decimal(string: price, locale: .enUSPOSIX)
                } else {
                    btcPrice = nil
                }
                return WalletOverview(usdValue: tokensValue, btcPrice: btcPrice)
            }()
            if secret == nil || hasPositiveBalanceToken || hasTransaction {
                snapshot.appendSections([.overview])
                snapshot.appendItems([.overview], toSection: .overview)
            } else {
                snapshot.appendSections([.emptyWalletInstruction])
                snapshot.appendItems([.emptyWalletInstruction], toSection: .emptyWalletInstruction)
            }
            
            if !tokens.isEmpty {
                snapshot.appendSections([.tokens])
                snapshot.appendItems(
                    displayTokens.values.map({ Item.token(assetID: $0.assetID) }),
                    toSection: .tokens
                )
            }
            if !transactions.isEmpty {
                snapshot.appendSections([.transactions])
                snapshot.appendItems(
                    displayTransactions.values.map({ Item.transaction(id: $0.transactionHash) }),
                    toSection: .transactions
                )
            }
            
            snapshot.appendSections([.support, .benefit])
            snapshot.appendItems(
                [.support(.contactUs), .support(.helpCenter)],
                toSection: .support
            )
            snapshot.appendItems(
                [.benefit(.commonWallet)],
                toSection: .benefit
            )
            
            let renaming = WalletDigest.LegacyClassicWalletRenaming(
                wallet: .common(wallet),
                hasLegacyAddress: addresses.contains { $0.path == nil }
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
                
                self.tokens = displayTokens
                self.tokensValue = formattedTokensValue
                self.hasMoreTokens = hasMoreToken
                
                self.transactions = displayTransactions
                self.transactionTokenSymbols = tokenSymbols
                self.hasMoreTransactions = hasMoreTransactions
                
                self.legacyRenaming = renaming
                switch renaming {
                case .required:
                    self.titleLabel.text = R.string.localizable.common_wallet()
                    self.renameLegacyClassicWallet()
                case .notInvolved, .done:
                    self.titleLabel.text = wallet.name
                }
                self.walletActionHandler = CommonWalletOverviewActionHandler(
                    wallet: wallet,
                    supportedChainIDs: chainIDs,
                    watchingAddresses: watchingAddresses,
                    tradeSource: .walletHome,
                    responder: self
                )
                self.insertTipsReferralSection(into: &snapshot)
                self.dataSource.applySnapshotUsingReloadData(snapshot)
                self.updateDappConnectionWalletIfNeeded()
            }
        }
    }
    
    @objc private func renamingInputChanged(_ sender: UITextField) {
        guard
            let controller = renamingInputController,
            let text = controller.textFields?.first?.text
        else {
            return
        }
        let count = text.utf8.count
        controller.actions[1].isEnabled = count > 0
            && count <= maxNameUTF8Count
            && text != wallet.name
    }
    
}

extension CommonWalletViewController: UITextFieldDelegate {
    
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let text = (textField.text ?? "") as NSString
        let newText = text.replacingCharacters(in: range, with: string)
        return newText.utf8.count <= maxNameUTF8Count
    }
    
}

extension CommonWalletViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        switch item {
        case .overview, .emptyWalletInstruction, .tip, .perpsPosition, .perpsTopMover, .referral, .benefit:
            break
        case .token(let assetID):
            if let token = tokens[assetID] {
                let viewController = Web3TokenViewController(
                    wallet: wallet,
                    token: token,
                    availability: availability
                )
                navigationController?.pushViewController(viewController, animated: true)
            }
        case .transaction(let id):
            if let transaction = transactions[id] {
                let viewController = Web3TransactionViewController(wallet: wallet, transaction: transaction)
                navigationController?.pushViewController(viewController, animated: true)
            }
        case .support(let support):
           request(support: support)
        }
    }
    
}

extension CommonWalletViewController {
    
    private func renameLegacyClassicWallet() {
        guard legacyRenaming == .required else {
            assertionFailure()
            return
        }
        // During the renaming process, the backend will check the state of the wallet.
        // If its category is classic and it has no path, the backend will assign
        // a default path with index 0. Therefore, after renaming, the wallet’s addresses
        // should be updated to avoid renaming it again.
        Logger.web3.info(category: "WalletView", message: "Will rename legacy wallet")
        let walletID = wallet.walletID
        Task { [weak self] in
            do {
                let wallet = try await RouteAPI.renameWallet(
                    id: walletID,
                    name: R.string.localizable.common_wallet()
                )
                Web3WalletDAO.shared.save(wallets: [wallet], addresses: [])
                let addresses = try await RouteAPI.addresses(walletID: walletID)
                Web3AddressDAO.shared.save(addresses: addresses)
                await MainActor.run {
                    guard let self else {
                        return
                    }
                    self.wallet = wallet
                    self.legacyRenaming = .done
                    self.titleLabel.text = wallet.name
                }
            } catch {
                Logger.web3.error(category: "WalletView", message: "Migrate: \(error)")
            }
        }
    }
    
    private func updateDappConnectionWalletIfNeeded() {
        switch availability {
        case .always:
            if AppGroupUserDefaults.Wallet.dappConnectionWalletID != wallet.walletID {
                AppGroupUserDefaults.Wallet.dappConnectionWalletID = wallet.walletID
                UIApplication.homeContainerViewController?.clipSwitcher.reloadWebViews()
                WalletConnectService.shared.updateSessions(with: wallet)
            }
        case .never, .afterImportingMnemonics, .afterImportingPrivateKey:
            break
        }
    }
    
    private func inputNewWalletName() {
        let input = UIAlertController(title: R.string.localizable.rename_wallet(), message: nil, preferredStyle: .alert)
        input.addTextField { textField in
            textField.text = self.wallet.name
            textField.addTarget(self, action: #selector(self.renamingInputChanged(_:)), for: .editingChanged)
            textField.delegate = self
        }
        input.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        let saveAction = UIAlertAction(title: R.string.localizable.save(), style: .default) { _ in
            self.renameWallet()
        }
        saveAction.isEnabled = false
        input.addAction(saveAction)
        renamingInputController = input
        present(input, animated: true)
    }
    
    private func renameWallet() {
        guard let name = renamingInputController?.textFields?.first?.text else {
            return
        }
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        RouteAPI.renameWallet(id: wallet.walletID, name: name, queue: .main) { [weak self] result in
            switch result {
            case let .success(wallet):
                DispatchQueue.global().async {
                    Web3WalletDAO.shared.save(wallets: [wallet], addresses: [])
                }
                if let self {
                    self.wallet = wallet
                    self.titleLabel.text = wallet.name
                }
                hud.set(style: .notification, text: R.string.localizable.changed())
            case let .failure(error):
                hud.set(style: .error, text: error.localizedDescription)
            }
            hud.scheduleAutoHidden()
        }
    }
    
    private func deleteWallet() {
        let deleteWallet = DeleteWalletViewController(wallet: wallet) { [weak self] in
            guard let self else {
                return
            }
            self.switchFromWallets(self)
        }
        let authentication = AuthenticationViewController(intent: deleteWallet)
        present(authentication, animated: true)
    }
    
    private func hide(token: Web3TokenItem) {
        DispatchQueue.global().async {
            Web3TokenExtraDAO.shared.hide(walletID: token.walletID, assetID: token.assetID)
        }
    }
    
}
