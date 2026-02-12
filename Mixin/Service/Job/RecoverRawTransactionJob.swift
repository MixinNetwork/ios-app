import Foundation
import MixinServices

final class RecoverRawTransactionJob: AsynchronousJob {
    
    override func getJobId() -> String {
        return "recover-raw-tx"
    }
    
    override func execute() -> Bool {
        Task {
            while let transaction = RawTransactionDAO.shared.firstUnspentRawTransaction(types: [.transfer, .withdrawal]) {
                Logger.general.info(category: "RecoverRawTransaction", message: "Found tx: \(transaction.requestID)")
                
                let feeTransaction: RawTransaction?
                if RawTransaction.TransactionType(rawValue: transaction.type) == .withdrawal {
                    let feeTraceID = UUID.uniqueObjectIDString(transaction.requestID, "FEE")
                    feeTransaction = RawTransactionDAO.shared.rawTransaction(with: feeTraceID)
                } else {
                    feeTransaction = nil
                }
                
                let requestIDs: [String]
                if let feeTransaction {
                    requestIDs = [transaction.requestID, feeTransaction.requestID]
                } else {
                    requestIDs = [transaction.requestID]
                }
                
                do {
                    _ = try await SafeAPI.transaction(id: transaction.requestID)
                    RawTransactionDAO.shared.signRawTransactions(requestIDs: requestIDs)
                    Logger.general.info(category: "RecoverRawTransaction", message: "Recovered by finding")
                } catch MixinAPIResponseError.notFound {
                    do {
                        var requests = [TransactionRequest(id: transaction.requestID, raw: transaction.rawTransaction)]
                        if let feeTransaction {
                            requests.append(TransactionRequest(id: feeTransaction.requestID, raw: feeTransaction.rawTransaction))
                        }
                        try await SafeAPI.postTransaction(requests: requests)
                        RawTransactionDAO.shared.signRawTransactions(requestIDs: requestIDs)
                        Logger.general.info(category: "RecoverRawTransaction", message: "Recovered by posting")
                    } catch {
                        Logger.general.error(category: "RecoverRawTransaction", message: "Error: \(error)")
                        try await Task.sleep(nanoseconds: 3 * NSEC_PER_SEC)
                    }
                } catch {
                    Logger.general.error(category: "RecoverRawTransaction", message: "Error: \(error)")
                    try await Task.sleep(nanoseconds: 3 * NSEC_PER_SEC)
                }
                
                // FIXME: Update AppGroupUserDefaults.Wallet.withdrawnAddressIds
            }
            Logger.general.info(category: "RecoverRawTransaction", message: "Finished")
            self.finishJob()
        }
        return true
    }
    
}
