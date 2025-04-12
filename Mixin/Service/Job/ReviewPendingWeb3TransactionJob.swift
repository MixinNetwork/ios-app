import Foundation
import MixinServices

final class ReviewPendingWeb3TransactionJob: BaseJob {
    
    override func getJobId() -> String {
        "review-pending-web3txn"
    }
    
    override func run() throws {
        let transactions = Web3RawTransactionDAO.shared.pendingRawTransactions()
        guard !transactions.isEmpty else {
            Logger.general.info(category: "ReviewPendingWeb3TransactionJob", message: "No pending txn")
            return
        }
        for transaction in transactions {
            let result = RouteAPI.transaction(
                chainID: transaction.chainID,
                hash: transaction.hash
            )
            switch result {
            case let .success(transaction):
                guard transaction.state.knownCase != .pending else {
                    return
                }
                
                try Web3RawTransactionDAO.shared.deleteRawTransaction(hash: transaction.hash) { db in
                    if transaction.state.knownCase == .notFound {
                        try Web3TransactionDAO.shared.setTransactionStatusNotFound(
                            hash: transaction.hash,
                            chain: transaction.chainID,
                            address: transaction.account,
                            db: db
                        )
                    }
                }
            case let .failure(error):
                Logger.general.debug(category: "ReviewPendingWeb3TransactionJob", message: "\(transaction.hash):\n\(error)")
            }
        }
    }
    
}
