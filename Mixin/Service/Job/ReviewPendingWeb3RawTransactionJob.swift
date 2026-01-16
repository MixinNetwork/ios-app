import Foundation
import MixinServices

final class ReviewPendingWeb3RawTransactionJob: BaseJob {
    
    private let walletID: String
    
    init(walletID: String) {
        self.walletID = walletID
        super.init()
    }
    
    static func jobID(walletID: String) -> String {
        "review-pending-Web3RawTxn-\(walletID)"
    }
    
    override func getJobId() -> String {
        Self.jobID(walletID: walletID)
    }
    
    override func run() throws {
        var transactions = Web3RawTransactionDAO.shared.pendingRawTransactions(walletID: walletID)
        while LoginManager.shared.isLoggedIn && !transactions.isEmpty {
            Logger.general.debug(category: "ReviewPendingWeb3RawTxn", message: "\(transactions.count) raw txns to review")
            for (i, transaction) in transactions.enumerated() {
                if isCancelled {
                    return
                }
                let result = RouteAPI.transaction(
                    chainID: transaction.chainID,
                    hash: transaction.hash
                )
                switch result {
                case let .success(transaction) where transaction.state.knownCase == .pending:
                    // Leave pending raw txn to next loop
                    Logger.general.debug(category: "ReviewPendingWeb3RawTxn", message: "Txn \(i) still pending")
                case let .success(transaction) where transaction.chainID == ChainID.bitcoin && transaction.state.knownCase == .notFound:
                    Logger.general.info(category: "ReviewPendingWeb3RawTxn", message: "BTC Txn \(i) not found")
                    try Web3RawTransactionDAO.shared.deleteRawTransaction(hash: transaction.hash) { db in
                        let txn = try Bitcoin.decode(transaction: transaction.raw)
                        for input in txn.inputs {
                            let id = Web3Output.bitcoinOutputID(txid: input.txid, vout: input.vout)
                            try Web3OutputDAO.shared.delete(id: id, db: db)
                            Logger.general.info(category: "ReviewPendingWeb3RawTxn", message: "Delete BTC Input: <id: \(id), Txid: \(input.txid), vout: \(input.vout)>")
                        }
                        if txn.numberOfOutputs > 1 {
                            let vout: Int = 1
                            let id = Web3Output.bitcoinOutputID(txid: transaction.hash, vout: vout)
                            try Web3OutputDAO.shared.delete(id: id, db: db)
                            Logger.general.info(category: "ReviewPendingWeb3RawTxn", message: "Delete BTC Change: <id: \(id), Txid: \(transaction.hash), vout: \(vout)>")
                        }
                        try Web3TransactionDAO.shared.setTransactionStatusNotFound(
                            hash: transaction.hash,
                            chainID: transaction.chainID,
                            address: transaction.account,
                            db: db
                        )
                    }
                    // XXX: Using hardcoded asset id. Safe for now
                    let refresh = SyncWeb3OutputJob(assetID: AssetID.btc, walletID: walletID)
                    ConcurrentJobQueue.shared.addJob(job: refresh)
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
