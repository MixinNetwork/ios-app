import UIKit
import MixinServices

final class Web3TokenViewController: TokenViewController<Web3TokenItem, Web3Transaction> {
    
    private var transactionTokenSymbols: [String: String] = [:]
    
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
        let reviewPendingTransactions = ReviewPendingWeb3TransactionJob()
        ConcurrentJobQueue.shared.addJob(job: reviewPendingTransactions)
        let syncTransactions = SyncWeb3TransactionJob(walletID: token.walletID)
        ConcurrentJobQueue.shared.addJob(job: syncTransactions)
    }
    
    override func send() {
        guard let chain = Web3Chain.chain(chainID: token.chainID) else {
            return
        }
        guard let address = Web3AddressDAO.shared.address(walletID: token.walletID, chainID: chain.chainID) else {
            return
        }
        let payment = Web3SendingTokenPayment(chain: chain, token: token, fromAddress: address.destination)
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
        cell.actionView.delegate = self
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
        let viewController = Web3TransactionViewController(walletID: token.walletID, transaction: transaction)
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    override func viewAllTransactions() {
        let history = Web3TransactionHistoryViewController(token: token)
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
        queue.async { [limit=transactionsCount, assetID=token.assetID, weak self] in
            let limitExceededTransactions = Web3TransactionDAO.shared.transactions(assetID: assetID, limit: limit + 1)
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
        switch action {
        case .receive:
            withMnemonicsBackupChecked { [token] in
                let selector = Web3ReceiveSourceViewController(token: token)
                self.navigationController?.pushViewController(selector, animated: true)
            }
        case .send:
            send()
        case .swap:
            let swap = Web3SwapViewController(sendAssetID: token.assetID, receiveAssetID: AssetID.erc20USDT, walletID: token.walletID)
            navigationController?.pushViewController(swap, animated: true)
            reporter.report(event: .swapStart, tags: ["entrance": "wallet", "source": "web3"])
        }
    }
    
}
