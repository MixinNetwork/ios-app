import UIKit
import MixinServices

final class Web3TokenViewController: TokenViewController<Web3TokenItem, Web3Transaction> {
    
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
    
    override func updateTransactionCell(_ cell: SnapshotCell, with transaction: Web3Transaction) {
//        cell.render(snapshot: transaction)
    }
    
    override func viewMarket() {
//        let market = MarketViewController(token: token, chartPoints: chartPoints)
//        market.pushingViewController = self
//        navigationController?.pushViewController(market, animated: true)
    }
    
    override func view(transaction: Web3Transaction) {
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
//            let dao: SafeSnapshotDAO = .shared
//
//            let limitExceededTransactionSnapshots = dao.snapshots(assetID: assetID, pending: false, limit: limit + 1)
//            let hasMoreSnapshots = limitExceededTransactionSnapshots.count > limit
//            let transactionSnapshots = Array(limitExceededTransactionSnapshots.prefix(limit))
//            let transactionRows = TransactionRow.rows(
//                transactions: transactionSnapshots,
//                hasMore: hasMoreSnapshots
//            )
            
//            DispatchQueue.main.async {
//                self?.reloadTransactions(pending: [], finished: transactionRows)
//            }
        }
    }
    
}

extension Web3TokenViewController: TokenActionView.Delegate {
    
    func tokenActionView(_ view: TokenActionView, wantsToPerformAction action: TokenAction) {
//        switch action {
//        case .receive:
//            let deposit = DepositViewController(token: token)
//            withMnemonicsBackupChecked {
//                self.navigationController?.pushViewController(deposit, animated: true)
//            }
//        case .send:
//            send()
//        case .swap:
//            let swap = MixinSwapViewController(sendAssetID: token.assetID, receiveAssetID: AssetID.erc20USDT)
//            navigationController?.pushViewController(swap, animated: true)
//            reporter.report(event: .swapStart, tags: ["entrance": "wallet", "source": "mixin"])
//        }
    }
    
}
