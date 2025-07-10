import Foundation
import MixinServices

final class ReviewPendingWeb3RawTransactionJob: BaseJob {
    
    private let walletID: String
    
    init(walletID: String) {
        self.walletID = walletID
        super.init()
    }
    
    override func getJobId() -> String {
        "review-pending-Web3RawTxn"
    }
    
    override func run() throws {
        var transactions = Web3RawTransactionDAO.shared.pendingRawTransactions(walletID: walletID)
        while LoginManager.shared.isLoggedIn && !transactions.isEmpty {
            Logger.general.debug(category: "ReviewPendingWeb3RawTxn", message: "\(transactions.count) raw txns to review")
            for (i, transaction) in transactions.enumerated() {
                let result = RouteAPI.transaction(
                    chainID: transaction.chainID,
                    hash: transaction.hash
                )
                switch result {
                case let .success(transaction) where transaction.state.knownCase == .pending:
                    // Leave pending raw txn to next loop
                    Logger.general.debug(category: "ReviewPendingWeb3RawTxn", message: "Txn \(i) still pending")
                case let .success(transaction):
                    // Delete not pending raw txn
                    Logger.general.debug(category: "ReviewPendingWeb3RawTxn", message: "Txn \(i) deleted")
                    try Web3RawTransactionDAO.shared.deleteRawTransaction(hash: transaction.hash) { db in
                        if transaction.state.knownCase == .notFound {
                            try Web3TransactionDAO.shared.setTransactionStatusNotFound(
                                hash: transaction.hash,
                                chainID: transaction.chainID,
                                address: transaction.account,
                                db: db
                            )
                        }
                    }
                case let .failure(error):
                    Logger.general.debug(category: "ReviewPendingWeb3RawTxn", message: "\(transaction.hash):\n\(error)")
                }
            }
            
            Thread.sleep(forTimeInterval: 3)
            if isCancelled {
                return
            }
            transactions = Web3RawTransactionDAO.shared.pendingRawTransactions(walletID: walletID)
        }
        Logger.general.info(category: "ReviewPendingWeb3RawTxn", message: "Ended")
    }
    
}
