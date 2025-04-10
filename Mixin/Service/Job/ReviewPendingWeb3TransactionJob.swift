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
                Web3TransactionDAO.shared.updateTransaction(
                    with: transaction.hash,
                    status: transaction.state
                ) { db in
                    try Web3RawTransactionDAO.shared.deleteRawTransaction(hash: transaction.hash, db: db)
                }
            case let .failure(error):
                Logger.general.debug(category: "ReviewPendingWeb3TransactionJob", message: "\(transaction.hash):\n\(error)")
            }
        }
    }
    
}
