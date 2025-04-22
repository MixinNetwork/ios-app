import Foundation
import MixinServices

final class SyncWeb3TransactionJob: BaseJob {
    
    private enum WalletError: Error {
        case emptyAddress
    }
    
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
        let addresses = Web3AddressDAO.shared.addresses(walletID: walletID)
        if addresses.isEmpty {
            switch RouteAPI.addresses(walletID: walletID) {
            case .success(let addresses):
                Web3AddressDAO.shared.save(addresses: addresses)
                reporter.report(error: WalletError.emptyAddress)
            case .failure(let error):
                throw error
            }
        }
        let destinations = Set(addresses.map(\.destination))
        Logger.general.debug(category: "SyncWeb3Txn", message: "Wallet: \(walletID), destinations: \(destinations)")
        for address in destinations {
            let initialOffset = Web3PropertiesDAO.shared.transactionOffset(address: address)
            Logger.general.debug(category: "SyncWeb3Txn", message: "Sync \(address) from initial offset: \(initialOffset ?? "(null)")")
            var result = RouteAPI.transactions(address: address, offset: initialOffset, limit: limit)
            while true {
                let transactions = try result.get()
                let offset = transactions.last?.createdAt
                Web3TransactionDAO.shared.save(transactions: transactions) { db in
                    if let offset {
                        try Web3PropertiesDAO.shared.set(
                            transactionOffset: offset,
                            forAddress: address,
                            db: db
                        )
                    }
                }
                
                if transactions.count > 0 {
                    let syncTokens = RefreshWeb3TokenJob(walletID: walletID)
                    ConcurrentJobQueue.shared.addJob(job: syncTokens)
                }
                
                Logger.general.debug(category: "SyncWeb3Txn", message: "Wrote \(transactions.count) txns to \(address), new offset: \(offset ?? "(null)")")
                if transactions.count < limit {
                    Logger.general.debug(category: "SyncWeb3Txn", message: "Sync \(address) finished")
                    break
                } else {
                    Logger.general.debug(category: "SyncWeb3Txn", message: "Sync \(address) from offset: \(offset ?? "(null)")")
                    result = RouteAPI.transactions(address: address, offset: offset, limit: limit)
                }
            }
        }
    }
    
}
