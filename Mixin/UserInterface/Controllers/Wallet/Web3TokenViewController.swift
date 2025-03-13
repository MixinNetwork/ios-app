import UIKit
import MixinServices

final class Web3TokenViewController: TokenViewController<Web3TokenItem, Web3TransactionItem> {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.titleView = NavigationTitleView(
            title: token.name,
            subtitle: token.depositNetworkName
        )
        
        // TODO: Subscribe token/transaction change notifications
        reloadSnapshots()
    }
    
    override func send() {
//        let receiver = TokenReceiverViewController(token: token)
//        navigationController?.pushViewController(receiver, animated: true)
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
    
    override func updateTransactionCell(_ cell: SnapshotCell, with transaction: Web3TransactionItem) {
        cell.render(transaction: transaction)
    }
    
    override func viewMarket() {
//        let market = MarketViewController(token: token, chartPoints: chartPoints)
//        market.pushingViewController = self
//        navigationController?.pushViewController(market, animated: true)
    }
    
    override func view(transaction: Web3TransactionItem) {
        let viewController = Web3TransactionViewController(token: token, transaction: transaction)
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    override func viewAllTransactions() {
//        let history = TransactionHistoryViewController(token: token)
//        navigationController?.pushViewController(history, animated: true)
    }
    
    private func reloadToken() {
        let assetID = token.assetID
        DispatchQueue.global().async { [weak self] in
//            guard let token = TokenDAO.shared.tokenItem(assetID: assetID) else {
//                return
//            }
//            DispatchQueue.main.sync {
//                guard let self = self else {
//                    return
//                }
//                self.token = token
//                let indexPath = IndexPath(row: 0, section: Section.balance.rawValue)
//                self.tableView.beginUpdates()
//                self.tableView.reloadRows(at: [indexPath], with: .none)
//                self.tableView.endUpdates()
//            }
        }
    }
    
    private func reloadSnapshots() {
        queue.async { [limit=transactionsCount, assetID=token.assetID, weak self] in
            let limitExceededTransactions = Web3TransactionDAO.shared.transactions(assetID: assetID, limit: limit + 1)
            let hasMoreTransactions = limitExceededTransactions.count > limit
            let transactions = Array(limitExceededTransactions.prefix(limit))
            let transactionRows = TransactionRow.rows(
                transactions: transactions,
                hasMore: hasMoreTransactions
            )
            DispatchQueue.main.async {
                self?.reloadTransactions(pending: [], finished: transactionRows)
            }
        }
    }
    
}

extension Web3TokenViewController: TokenActionView.Delegate {
    
    func tokenActionView(_ view: TokenActionView, wantsToPerformAction action: TokenAction) {
        switch action {
        case .receive:
            withMnemonicsBackupChecked {
                
            }
        case .send:
            send()
        case .swap:
            break
        }
    }
    
}
