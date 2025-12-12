import UIKit
import MixinServices

final class CommonWalletViewController: WalletViewController {
    
    private enum Secret {
        case mnemonics(EncryptedBIP39Mnemonics)
        case privateKey(EncryptedPrivateKey, Web3Chain.Kind)
    }
    
    private let maxNameUTF8Count = 32
    
    private var wallet: Web3Wallet
    private var secret: Secret?
    private var supportedChainIDs: Set<String> = []
    private var tokens: [Web3TokenItem] = []
    private var legacyRenaming: WalletDigest.LegacyClassicWalletRenaming?
    private var watchingAddresses: WatchingAddresses?
    
    private var reviewPendingTransactionJobID: String?
    
    private weak var renamingInputController: UIAlertController?
    
    private var availability: Web3Wallet.Availability {
        switch wallet.category.knownCase {
        case .classic:
                .always
        case .importedMnemonic:
            if secret == nil {
                .afterImportingMnemonics
            } else {
                .always
            }
        case .importedPrivateKey:
            if secret == nil {
                .afterImportingPrivateKey
            } else {
                .always
            }
        case .watchAddress, .mixinSafe, .none:
                .never
        }
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
        tableView.dataSource = self
        tableView.delegate = self
        tableHeaderView.actionView.actions = [.buy, .receive, .send, .swap]
        switch wallet.category.knownCase {
        case .classic:
            tableHeaderView.actionView.isHidden = false
        case .importedMnemonic, .importedPrivateKey, .mixinSafe, .none:
            tableHeaderView.actionView.isHidden = true
        case .watchAddress:
            addIconIntoTitleView(image: R.image.watching_wallet())
            tableHeaderView.actionView.isHidden = true
        }
        tableHeaderView.delegate = self
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
            name: Web3TransactionDAO.transactionDidSaveNotification,
            object: nil
        )
        
        reloadData()
        reloadPendingTransactions()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadTokensFromRemote()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let walletID = wallet.walletID
        let jobs = [
            ReviewPendingWeb3RawTransactionJob(walletID: walletID),
            ReviewPendingWeb3TransactionJob(walletID: walletID),
        ]
        reviewPendingTransactionJobID = jobs[1].getJobId()
        for job in jobs {
            ConcurrentJobQueue.shared.addJob(job: job)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let id = reviewPendingTransactionJobID {
            ConcurrentJobQueue.shared.cancelJob(jobId: id)
        }
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
        case .mixinSafe:
            return
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
    
    override func makeSearchViewController() -> UIViewController {
        let modelController = WalletSearchWeb3TokenController(
            walletID: wallet.walletID,
            supportedChainIDs: supportedChainIDs
        )
        modelController.delegate = self
        let viewController = WalletSearchViewController(modelController: modelController)
        return viewController
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
            let secret: Secret?
            let chainIDs = Set(addresses.map(\.chainID))
            let tokens = Web3TokenDAO.shared.notHiddenTokens(
                walletID: walletID,
                includesZeroBalanceItems: true
            )
            let renaming = WalletDigest.LegacyClassicWalletRenaming(
                wallet: .common(wallet),
                hasLegacyAddress: addresses.contains { $0.path == nil }
            )
            let watchingAddresses: WatchingAddresses?
            switch wallet.category.knownCase {
            case .mixinSafe:
                return
            case .classic:
                secret = nil
                watchingAddresses = nil
            case .importedMnemonic:
                if let mnemonics = AppGroupKeychain.importedMnemonics(walletID: walletID) {
                    secret = .mnemonics(mnemonics)
                } else {
                    secret = nil
                }
                watchingAddresses = nil
            case .importedPrivateKey:
                if let privateKey = AppGroupKeychain.importedPrivateKey(walletID: walletID) {
                    let kind: Web3Chain.Kind? = .singleKindWallet(chainIDs: chainIDs)
                    switch kind {
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
                watchingAddresses = nil
            case .watchAddress, .none:
                secret = nil
                watchingAddresses = WatchingAddresses(addresses: addresses)
            }
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.secret = secret
                self.supportedChainIDs = chainIDs
                self.tokens = tokens
                self.legacyRenaming = renaming
                self.watchingAddresses = watchingAddresses
                switch renaming {
                case .required:
                    self.titleLabel.text = R.string.localizable.common_wallet()
                    self.renameLegacyClassicWallet()
                case .notInvolved, .done:
                    self.titleLabel.text = wallet.name
                }
                self.tableHeaderView.reloadValues(tokens: tokens)
                if let watchingAddresses {
                    self.tableHeaderView.actionView.isHidden = true
                    let description = R.string.localizable.you_are_watching_address(
                        watchingAddresses.prettyFormatted
                    )
                    self.tableHeaderView.showWatchingIndicator(description: description)
                } else {
                    self.tableHeaderView.actionView.isHidden = false
                    self.tableHeaderView.hideWatchingIndicator()
                }
                self.layoutTableHeaderView()
                self.tableView.reloadData()
                self.updateDappConnectionWalletIfNeeded()
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
                self.tableHeaderView.reloadPendingTransactions(transactions)
                self.layoutTableHeaderView()
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

extension CommonWalletViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tokens.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let token = tokens[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.asset, for: indexPath)!
        cell.render(web3Token: token)
        return cell
    }
    
}

extension CommonWalletViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let token = tokens[indexPath.row]
        let viewController = Web3TokenViewController(
            wallet: wallet,
            token: token,
            availability: availability
        )
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

extension CommonWalletViewController: WalletHeaderView.Delegate {
    
    func walletHeaderView(_ view: WalletHeaderView, didSelectAction action: TokenAction) {
        switch availability {
        case .always:
            break
        case .never:
            return
        case .afterImportingMnemonics:
            let tip = PopupTipViewController(tip: .importMnemonics(wallet))
            present(tip, animated: true)
            return
        case .afterImportingPrivateKey:
            let tip = PopupTipViewController(tip: .importPrivateKey(wallet))
            present(tip, animated: true)
            return
        }
        switch action {
        case .buy:
            let buy = BuyTokenInputAmountViewController(wallet: .common(wallet))
            navigationController?.pushViewController(buy, animated: true)
        case .send:
            let selector = Web3TokenSelectorViewController(
                wallet: wallet,
                supportedChainIDs: supportedChainIDs,
                intent: .send,
            )
            selector.onSelected = { [wallet] token in
                guard
                    let chain = Web3Chain.chain(chainID: token.chainID),
                    let address = Web3AddressDAO.shared.address(walletID: wallet.walletID, chainID: chain.chainID)
                else {
                    return
                }
                let payment = Web3SendingTokenPayment(
                    wallet: wallet,
                    chain: chain,
                    token: token,
                    fromAddress: address
                )
                let selector = Web3TokenReceiverViewController(payment: payment)
                self.navigationController?.pushViewController(selector, animated: true)
            }
            present(selector, animated: true, completion: nil)
        case .receive:
            let selector = Web3TokenSelectorViewController(
                wallet: wallet,
                supportedChainIDs: supportedChainIDs,
                intent: .receive,
            )
            selector.onSelected = { [wallet] token in
                let selector = Web3TokenSenderSelectorViewController(
                    receivingWallet: wallet,
                    receivingToken: token
                )
                self.navigationController?.pushViewController(selector, animated: true)
            }
            withMnemonicsBackupChecked {
                self.present(selector, animated: true, completion: nil)
            }
        case .swap:
            let swap = Web3TradeViewController(
                wallet: wallet,
                supportedChainIDs: supportedChainIDs,
                sendAssetID: nil,
                receiveAssetID: nil
            )
            navigationController?.pushViewController(swap, animated: true)
            reporter.report(event: .tradeStart, tags: ["wallet": "web3", "source": "wallet_home"])
        }
    }
    
    func walletHeaderViewWantsToRevealPendingDeposits(_ view: WalletHeaderView) {
        let transactionHistory = Web3TransactionHistoryViewController(wallet: wallet, type: .pending)
        navigationController?.pushViewController(transactionHistory, animated: true)
    }
    
    func walletHeaderViewWantsToRevealWatchingAddresses(_ view: WalletHeaderView) {
        guard let addresses = watchingAddresses?.addresses, !addresses.isEmpty else {
            return
        }
        let description = WatchWalletAddressesViewController(addresses: addresses)
        navigationController?.pushViewController(description, animated: true)
    }
    
}

extension CommonWalletViewController: WalletSearchWeb3TokenController.Delegate {
    
    func walletSearchWeb3TokenController(_ controller: WalletSearchWeb3TokenController, didSelectToken token: Web3TokenItem) {
        let controller = Web3TokenViewController(
            wallet: wallet,
            token: token,
            availability: availability
        )
        navigationController?.pushViewController(controller, animated: true)
    }
    
    func walletSearchWeb3TokenController(_ controller: WalletSearchWeb3TokenController, didSelectTrendingItem item: AssetItem) {
        let walletID = wallet.walletID
        if let item = Web3TokenDAO.shared.token(walletID: walletID, assetID: item.assetId) {
            walletSearchWeb3TokenController(controller, didSelectToken: item)
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
                case .failure(let error):
                    report(error: error)
                case .success(let token):
                    let item = Web3TokenItem(
                        token: Web3Token(
                            walletID: walletID,
                            assetID: token.assetID,
                            chainID: token.chainID,
                            assetKey: token.assetKey,
                            kernelAssetID: token.kernelAssetID,
                            symbol: token.symbol,
                            name: token.name,
                            precision: token.precision,
                            iconURL: token.iconURL,
                            amount: "0",
                            usdPrice: token.usdPrice,
                            usdChange: token.usdChange,
                            level: Web3Reputation.Level.verified.rawValue
                        ),
                        hidden: false,
                        chain: chain
                    )
                    DispatchQueue.main.sync {
                        hud.hide()
                        self?.walletSearchWeb3TokenController(controller, didSelectToken: item)
                    }
                }
            }
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
    
    private func hideToken(with assetID: String) {
        guard let index = tokens.firstIndex(where: { $0.assetID == assetID }) else {
            return
        }
        let token = tokens.remove(at: index)
        tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .fade)
        DispatchQueue.global().async {
            Web3TokenExtraDAO.shared.hide(walletID: token.walletID, assetID: token.assetID)
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
    
}
