import Foundation
import MixinServices

final class ReviewPendingWeb3TransactionJob: BaseJob {
    
    override func getJobId() -> String {
        "review-pending-web3txn"
    }
    
    override func run() throws {
        let transactions = Web3RawTransactionDAO.shared.pendingTransactions()
        guard !transactions.isEmpty else {
            Logger.general.info(category: "ReviewPendingWeb3TransactionJob", message: "No pending txn")
            return
        }
        for transaction in transactions {
            let result = RouteAPI.transaction(
                chainID: transaction.chainID,
                hash: transaction.hash
            )
            let transactionChanged: Bool
            switch result {
            case let .success(transaction):
                transactionChanged = transaction.state.knownCase != .pending
            case .failure(.response(.notFound)):
                transactionChanged = true
            case let .failure(error):
                transactionChanged = false
                Logger.general.info(category: "ReviewPendingWeb3TransactionJob", message: "\(transaction.hash):\n\(error)")
            }
            if transactionChanged {
                Logger.general.info(category: "ReviewPendingWeb3TransactionJob", message: "Deleted \(transaction.hash)")
                Web3RawTransactionDAO.shared.deleteTransaction(hash: transaction.hash)
            }
        }
    }
    
}
