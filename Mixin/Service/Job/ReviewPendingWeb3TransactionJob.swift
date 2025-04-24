import Foundation
import MixinServices

final class ReviewPendingWeb3TransactionJob: BaseJob {
    
    private let walletID: String
    
    init(walletID: String) {
        self.walletID = walletID
        super.init()
    }
    
    override func getJobId() -> String {
        "review-pending-Web3Txn"
    }
    
    override func run() throws {
        var transactions = Web3TransactionDAO.shared.pendingTransactions()
        while LoginManager.shared.isLoggedIn && !transactions.isEmpty {
            Logger.general.debug(category: "ReviewPendingWeb3Txn", message: "\(transactions.count) txns to review")
            let hashes = transactions.map(\.transactionHash)
            let rawTransactionsCount = Web3RawTransactionDAO.shared
                .pendingRawTransactionsCount(hashIn: hashes)
            
            if rawTransactionsCount == transactions.count {
                // All pending txns have a corresponding raw txn
                // Wait until `ReviewPendingWeb3RawTransactionJob` finishes
                Logger.general.debug(category: "ReviewPendingWeb3Txn", message: "Leave \(transactions.count) txns to raw txn reviewer")
            } else {
                Logger.general.debug(category: "ReviewPendingWeb3Txn", message: "\(transactions.count - rawTransactionsCount) txns don't have raw txn, sync it")
                let jobs = [
                    RefreshWeb3TokenJob(walletID: walletID),
                    SyncWeb3TransactionJob(walletID: walletID),
                ]
                for job in jobs {
                    ConcurrentJobQueue.shared.addJob(job: job)
                }
            }
            
            Thread.sleep(forTimeInterval: 5)
            if isCancelled {
                return
            }
            transactions = Web3TransactionDAO.shared.pendingTransactions()
        }
        Logger.general.info(category: "ReviewPendingWeb3Txn", message: "Ended")
    }
    
}
