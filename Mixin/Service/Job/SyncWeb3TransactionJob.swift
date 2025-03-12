import Foundation
import MixinServices

final class SyncWeb3TransactionJob: BaseJob {
    
    private let limit = 300
    private let walletID: String
    
    init(walletID: String) {
        self.walletID = walletID
        super.init()
    }
    
    override func getJobId() -> String {
        "sync-web3txn-\(walletID)"
    }
    
    override func run() throws {
        switch RouteAPI.addresses(walletID: walletID) {
        case .failure(let error):
            throw error
        case .success(let addresses):
            Logger.general.debug(category: "SyncWeb3Txn", message: "Wallet: \(walletID), addresses: \(addresses)")
            for address in Set(addresses.map(\.destination)) {
                let initialOffset = Web3PropertiesDAO.shared.transactionOffset(address: address)
                Logger.general.debug(category: "SyncWeb3Txn", message: "Sync \(address) from initial offset: \(initialOffset ?? "(null)")")
                var result = RouteAPI.transactions(address: address, limit: limit)
                while true {
                    let transactions = try result.get()
                    let offset = transactions.last?.createdAt
                    Logger.general.debug(category: "SyncWeb3Txn", message: "Write \(transactions.count) transactions to \(address), new offset: \(offset ?? "(null)")")
                    Web3TransactionDAO.shared.save(transactions: transactions) { db in
                        if let offset {
                            try Web3PropertiesDAO.shared.set(
                                transactionOffset: offset,
                                forAddress: address,
                                db: db
                            )
                        }
                    }
                    if transactions.count < limit {
                        Logger.general.debug(category: "SyncWeb3Txn", message: "Sync \(address) finished")
                        break
                    } else {
                        Logger.general.debug(category: "SyncWeb3Txn", message: "Sync \(address) from offset: \(offset ?? "(null)")")
                        result = RouteAPI.transactions(address: address, limit: limit)
                    }
                }
            }
        }
    }
    
}
