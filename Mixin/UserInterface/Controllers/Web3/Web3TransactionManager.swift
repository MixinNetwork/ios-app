import Foundation
import MixinServices

final class Web3TransactionManager {
    
    static let shared = Web3TransactionManager()
    
    func syncPendingTransaction(walletID: String, transaction: Web3Transaction) -> Task<Void, Error>? {
        Task {
            repeat {
                guard let localTransaction = await Self.syncPendingTransaction(walletID: walletID, transaction: transaction) else {
                    return
                }
                guard localTransaction.status == .pending else {
                    return
                }
                
                let syncTransactions = SyncWeb3TransactionJob(walletID: walletID)
                ConcurrentJobQueue.shared.addJob(job: syncTransactions)
                try await Task.sleep(nanoseconds: 3 * NSEC_PER_SEC)
            } while !Task.isCancelled
        }
    }
    
    func syncPendingTransaction(walletID: String) -> Task<Void, Error>? {
        Task {
            var transactions: [Web3Transaction] = []
            repeat {
                transactions = Web3TransactionDAO.shared.pendingTransactions()
                
                if transactions.count > 0 {
                    for transaction in transactions {
                        _ = await Self.syncPendingTransaction(walletID: walletID, transaction: transaction)
                    }
                    
                    let syncTransactions = SyncWeb3TransactionJob(walletID: walletID)
                    ConcurrentJobQueue.shared.addJob(job: syncTransactions)
                    try await Task.sleep(nanoseconds: 3 * NSEC_PER_SEC)
                }
            } while !Task.isCancelled && transactions.count > 0
        }
    }
    
    private class func syncPendingTransaction(walletID: String, transaction: Web3Transaction) async -> Web3Transaction? {
        let localTransaction = Web3TransactionDAO.shared.transaction(
            hash: transaction.transactionHash,
            chainID: transaction.chainID,
            address: transaction.address
        )
        guard let localTransaction else {
            return nil
        }
        guard localTransaction.status == .pending else {
            return localTransaction
        }
        guard Web3RawTransactionDAO.shared.rawTransactionExists(hash: transaction.transactionHash) else {
            return localTransaction
        }
        
        do {
            let transaction = try await RouteAPI.transaction(
                chainID: transaction.chainID,
                hash: transaction.transactionHash
            )
            if transaction.state.knownCase != .pending {
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
            }
        } catch {
            Logger.general.debug(category: "Web3TransactionManager", message: "\(error)")
        }
        return localTransaction
    }
}
