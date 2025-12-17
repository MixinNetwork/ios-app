import Foundation
import MixinServices

final class SyncWeb3AddressJob: BaseJob {
    
    private let walletID: String
    
    init(walletID: String) {
        self.walletID = walletID
        super.init()
    }
    
    static func jobID(walletID: String) -> String {
        "sync-web3address-\(walletID)"
    }
    
    override func getJobId() -> String {
        Self.jobID(walletID: walletID)
    }
    
    override func run() throws {
        switch RouteAPI.addresses(walletID: walletID) {
        case .success(let addresses):
            Web3AddressDAO.shared.save(addresses: addresses)
        case .failure(let error):
            throw error
        }
    }
    
}
