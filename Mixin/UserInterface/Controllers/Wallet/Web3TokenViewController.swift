import UIKit
import MixinServices

final class Web3TokenViewController: TokenViewController<Web3TokenItem, Web3Transaction> {
    
    private let wallet: Web3Wallet
    private let availability: Web3Wallet.Availability
    
    private var transactionTokenSymbols: [String: String] = [:]
    private var reviewPendingTransactionJobID: String?
    
    init(wallet: Web3Wallet, token: Web3TokenItem, availability: Web3Wallet.Availability) {
        self.wallet = wallet
        self.availability = availability
        super.init(token: token)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.titleView = NavigationTitleView(
            title: token.name,
            subtitle: token.depositNetworkName
        )
        tableView.register(R.nib.web3TransactionCell)
        tableView.reloadData()
        
        let notificationCenter: NotificationCenter = .default
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadToken),
            name: Web3TokenDAO.tokensDidChangeNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadSnapshots),
            name: Web3TokenDAO.tokensDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadIfContains(_:)),
            name: Web3TransactionDAO.transactionDidSaveNotification,
            object: nil
        )
        
        reloadSnapshots()
        let refreshToken = RefreshWeb3TokenJob(token: token)
        ConcurrentJobQueue.shared.addJob(job: refreshToken)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let walletID = token.walletID
        let jobs = [
            SyncWeb3TransactionJob(walletID: walletID),
            ReviewPendingWeb3RawTransactionJob(walletID: walletID),
            ReviewPendingWeb3TransactionJob(walletID: walletID),
        ]
        reviewPendingTransactionJobID = jobs[2].getJobId()
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
    
    override func send() {
        guard
            let chain = Web3Chain.chain(chainID: token.chainID),
            let wallet = Web3WalletDAO.shared.wallet(id: token.walletID),
            let address = Web3AddressDAO.shared.address(walletID: token.walletID, chainID: chain.chainID)
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
    
    override func setTokenHidden(_ hidden: Bool) {
        DispatchQueue.global().async { [token] in
            let dao: Web3TokenExtraDAO = .shared
            if hidden {
                dao.hide(walletID: token.walletID, assetID: token.assetID)
            } else {
                dao.unhide(walletID: token.walletID, assetID: token.assetID)
            }
        }
    }
    
    override func updateBalanceCell(_ cell: TokenBalanceCell) {
        cell.reloadData(web3Token: token)
        switch availability {
        case .always, .afterImportingMnemonics, .afterImportingPrivateKey:
            cell.showActionView()
            cell.actionView.delegate = self
        case .never:
            cell.hideActionView()
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForTransaction transaction: Web3Transaction) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.web3_transaction.identifier) as! Web3TransactionCell
        cell.load(transaction: transaction, symbols: transactionTokenSymbols)
        return cell
    }
    
    override func viewMarket() {
        let market = MarketViewController(token: token, chartPoints: chartPoints)
        market.pushingViewController = self
        navigationController?.pushViewController(market, animated: true)
    }
    
    override func view(transaction: Web3Transaction) {
        let viewController = Web3TransactionViewController(wallet: wallet, transaction: transaction)
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    override func viewAllTransactions() {
        let history = Web3TransactionHistoryViewController(wallet: wallet, token: token)
        navigationController?.pushViewController(history, animated: true)
    }
    
    @objc private func reloadToken() {
        DispatchQueue.global().async { [token, weak self] in
            guard let token = Web3TokenDAO.shared.token(walletID: token.walletID, assetID: token.assetID) else {
                return
            }
            DispatchQueue.main.sync {
                guard let self = self else {
                    return
                }
                self.token = token
                let indexPath = IndexPath(row: 0, section: Section.balance.rawValue)
                self.tableView.beginUpdates()
                self.tableView.reloadRows(at: [indexPath], with: .none)
                self.tableView.endUpdates()
            }
        }
    }
    
    @objc private func reloadSnapshots() {
        queue.async { [limit=transactionsCount, token, weak self] in
            let limitExceededTransactions = Web3TransactionDAO.shared.transactions(
                walletID: token.walletID,
                assetID: token.assetID,
                limit: limit + 1
            )
            let hasMoreTransactions = limitExceededTransactions.count > limit
            let transactions = Array(limitExceededTransactions.prefix(limit))
            let transactionRows = TransactionRow.rows(
                transactions: transactions,
                hasMore: hasMoreTransactions
            )
            var assetIDs: Set<String> = []
            for transaction in transactions {
                assetIDs.formUnion(transaction.allAssetIDs)
            }
            let tokenSymbols = Web3TokenDAO.shared.tokenSymbols(ids: assetIDs)
                .mapValues { symbol in
                    TextTruncation.truncateTail(string: symbol, prefixCount: 8)
                }
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.transactionTokenSymbols = tokenSymbols
                self.reloadTransactions(pending: [], finished: transactionRows)
            }
        }
    }
    
    @objc private func reloadIfContains(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let transactions = userInfo[Web3TransactionDAO.transactionsUserInfoKey] as? [Web3Transaction],
            transactions.contains(where: { [$0.sendAssetID, $0.receiveAssetID].contains(token.assetID) })
        else {
            return
        }
        reloadSnapshots()
    }
    
}

extension Web3TokenViewController: TokenActionView.Delegate {
    
    func tokenActionView(_ view: TokenActionView, wantsToPerformAction action: TokenAction) {
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
        case .receive:
            withMnemonicsBackupChecked { [wallet, token] in
                let selector = Web3TokenSenderSelectorViewController(
                    receivingWallet: wallet,
                    receivingToken: token
                )
                self.navigationController?.pushViewController(selector, animated: true)
            }
        case .send:
            send()
        case .swap:
            let swap = Web3SwapViewController(
                wallet: wallet,
                mode: .simple,
                sendAssetID: token.assetID,
                receiveAssetID: AssetID.erc20USDT,
            )
            navigationController?.pushViewController(swap, animated: true)
            reporter.report(event: .tradeStart, tags: ["wallet": "web3", "source": "asset_detail"])
        case .buy:
            break
        }
    }
    
}
