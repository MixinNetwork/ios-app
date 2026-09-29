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
            Logger.web3.debug(category: "ReviewPendingWeb3RawTxn", message: "\(transactions.count) raw txns to review")
            for transaction in transactions {
                if isCancelled {
                    return
                }
                if transaction.isGaslessSponsorTransaction {
                    try reviewGaslessSponsorTransaction(transaction)
                } else {
                    try reviewNativeTransaction(
                        transaction,
                        utxoOutputIDsOccupiedByOtherTransactions: Set(
                            transactions.compactMap { (tx) -> [String]? in
                                guard tx.hash != transaction.hash else {
                                    return nil
                                }
                                if tx.chainID == ChainID.bitcoin {
                                    do {
                                        return try Bitcoin.decode(transaction: tx.raw).inputs.map(\.outputID)
                                    } catch {
                                        Logger.web3.error(category: "ReviewPendingWeb3RawTxn", message: "Decode btc txn: \(error)")
                                        return nil
                                    }
                                } else if tx.chainID == ChainID.pearl {
                                    do {
                                        return try Pearl.decode(transaction: tx.raw).inputs.map(\.outputID)
                                    } catch {
                                        Logger.web3.error(category: "ReviewPendingWeb3RawTxn", message: "Decode pearl txn: \(error)")
                                        return nil
                                    }
                                } else {
                                    return nil
                                }
                            }.flatMap { $0 }
                        )
                    )
                }
            }
            Thread.sleep(forTimeInterval: 3)
            if isCancelled {
                return
            }
            transactions = Web3RawTransactionDAO.shared.pendingRawTransactions(walletID: walletID)
        }
        Logger.web3.info(category: "ReviewPendingWeb3RawTxn", message: "Ended")
    }
    
    private func reviewGaslessSponsorTransaction(
        _ transaction: Web3RawTransaction,
    ) throws {
        let sponsorTxID = transaction.hash
        switch RouteAPI.gaslessTransaction(id: sponsorTxID) {
        case .success(let tx):
            if let broadcastTxHash = tx.broadcastTxHash, !broadcastTxHash.isEmpty {
                Logger.web3.info(category: "ReviewPendingWeb3RawTxn", message: "Got broadcast tx hash for \(sponsorTxID)")
                Web3TransactionDAO.shared.updateGaslessSponsorTransaction(
                    sponsorTxID: sponsorTxID,
                    chainID: transaction.chainID,
                    address: transaction.account,
                    broadcastTxHash: broadcastTxHash
                ) { db in
                    try Web3RawTransactionDAO.shared.updateGaslessSponsorTransaction(
                        sponsorTxID: sponsorTxID,
                        broadcastTxHash: broadcastTxHash,
                        db: db
                    )
                }
            } else {
                Logger.web3.warn(category: "ReviewPendingWeb3RawTxn", message: "No broadcast tx hash")
            }
        case .failure(let error):
            Logger.web3.error(category: "ReviewPendingWeb3RawTxn", message: "\(transaction.hash):\n\(error)")
        }
    }
    
    private func reviewNativeTransaction(
        _ rawTransaction: Web3RawTransaction,
        utxoOutputIDsOccupiedByOtherTransactions: @autoclosure () -> Set<String>,
    ) throws {
        let result = RouteAPI.transaction(
            chainID: rawTransaction.chainID,
            hash: rawTransaction.hash
        )
        switch result {
        case let .success(transaction) where transaction.state.knownCase == .pending:
            // Leave pending raw txn to next loop
            Logger.web3.debug(category: "ReviewPendingWeb3RawTxn", message: "Txn still pending \(transaction.hash)")
        case let .success(transaction) where rawTransaction.chainID == ChainID.bitcoin && transaction.state.knownCase == .notFound:
            Logger.web3.info(category: "ReviewPendingWeb3RawTxn", message: "BTC Txn not found \(rawTransaction.hash)")
            let outputIDsOccupiedByOtherTransactions = utxoOutputIDsOccupiedByOtherTransactions()
            try Web3RawTransactionDAO.shared.deleteRawTransaction(hash: rawTransaction.hash) { db in
                let txn = try Bitcoin.decode(transaction: rawTransaction.raw)
                
                // Do not delete the output if it's also used in other transactions, which possibly be RBF ones.
                // Otherwise, when `SyncWeb3OutputJob` is executed, there could be an unspent output gets inserted,
                // which should be blocked by a local record with status of 'signed'
                for input in txn.inputs where !outputIDsOccupiedByOtherTransactions.contains(input.outputID) {
                    try Web3OutputDAO.shared.delete(id: input.outputID, db: db)
                    Logger.web3.info(category: "ReviewPendingWeb3RawTxn", message: "Delete BTC Input: <id: \(input.outputID), Txid: \(input.txid), vout: \(input.vout)>")
                }
                for (vout, output) in txn.outputs.enumerated() where output.address == rawTransaction.account {
                    let id = Web3Output.bitcoinOutputID(txid: rawTransaction.hash, vout: vout)
                    try Web3OutputDAO.shared.delete(id: id, db: db)
                    Logger.web3.info(category: "ReviewPendingWeb3RawTxn", message: "Delete BTC Output: <id: \(id), Txid: \(rawTransaction.hash), vout: \(vout)>")
                }
                try Web3TransactionDAO.shared.setTransactionStatusNotFound(
                    hash: rawTransaction.hash,
                    chainID: rawTransaction.chainID,
                    address: rawTransaction.account,
                    db: db
                )
            }
            let refresh = SyncWeb3OutputJob(assetID: AssetID.btc, walletID: walletID)
            ConcurrentJobQueue.shared.addJob(job: refresh)
        case let .success(transaction) where rawTransaction.chainID == ChainID.pearl && transaction.state.knownCase == .notFound:
            Logger.web3.info(category: "ReviewPendingWeb3RawTxn", message: "Pearl Txn not found \(rawTransaction.hash)")
            let outputIDsOccupiedByOtherTransactions = utxoOutputIDsOccupiedByOtherTransactions()
            try Web3RawTransactionDAO.shared.deleteRawTransaction(hash: rawTransaction.hash) { db in
                let txn = try Pearl.decode(transaction: rawTransaction.raw)
                
                for input in txn.inputs where !outputIDsOccupiedByOtherTransactions.contains(input.outputID) {
                    try Web3OutputDAO.shared.delete(id: input.outputID, db: db)
                    Logger.web3.info(category: "ReviewPendingWeb3RawTxn", message: "Delete Pearl Input: <id: \(input.outputID), Txid: \(input.txid), vout: \(input.vout)>")
                }
                for (vout, output) in txn.outputs.enumerated() where output.address == rawTransaction.account {
                    let id = Web3Output.pearlOutputID(txid: rawTransaction.hash, vout: vout)
                    try Web3OutputDAO.shared.delete(id: id, db: db)
                    Logger.web3.info(category: "ReviewPendingWeb3RawTxn", message: "Delete Pearl Output: <id: \(id), Txid: \(rawTransaction.hash), vout: \(vout)>")
                }
                try Web3TransactionDAO.shared.setTransactionStatusNotFound(
                    hash: rawTransaction.hash,
                    chainID: rawTransaction.chainID,
                    address: rawTransaction.account,
                    db: db
                )
            }
            let refresh = SyncWeb3OutputJob(assetID: AssetID.pearl, walletID: walletID)
            ConcurrentJobQueue.shared.addJob(job: refresh)
        case let .success(transaction):
            // Delete not pending raw txn
            Logger.web3.info(category: "ReviewPendingWeb3RawTxn", message: "Delete tx \(rawTransaction.hash), state: \(transaction.state.rawValue). Returned hash: \(transaction.hash), chainID: \(rawTransaction.chainID)<->\(transaction.chainID), address: \(rawTransaction.account)<->\(transaction.account)")
            try Web3RawTransactionDAO.shared.deleteRawTransaction(hash: rawTransaction.hash) { db in
                switch transaction.state.knownCase {
                case .notFound:
                    Logger.web3.info(category: "ReviewPendingWeb3RawTxn", message: "Updating to not found")
                    try Web3TransactionDAO.shared.setTransactionStatusNotFound(
                        hash: rawTransaction.hash,
                        chainID: rawTransaction.chainID,
                        address: rawTransaction.account,
                        db: db
                    )
                default:
                    Logger.web3.info(category: "ReviewPendingWeb3RawTxn", message: "Not updating to not found")
                }
            }
        case let .failure(error):
            Logger.web3.error(category: "ReviewPendingWeb3RawTxn", message: "\(rawTransaction.hash):\n\(error)")
        }
    }
    
}
