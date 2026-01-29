import Foundation
import MixinServices

final class SyncWeb3OutputJob: AsynchronousJob {
    
    private let assetID: String
    private let walletID: String
    
    init(assetID: String, walletID: String) {
        self.assetID = assetID
        self.walletID = walletID
        super.init()
    }
    
    public override func getJobId() -> String {
        "sync-web3outputs-\(walletID)"
    }
    
    public override func execute() -> Bool {
        guard let address = Web3AddressDAO.shared.address(walletID: walletID, chainID: ChainID.bitcoin) else {
            return false
        }
        Logger.general.debug(category: "SyncWeb3Output", message: "wid: \(walletID), addr: \(address.destination)")
        RouteAPI.walletOutputs(
            assetID: assetID,
            address: address.destination,
            queue: .global(),
        ) { [walletID, assetID] result in
            switch result {
            case let .success(outputs):
                // Simplfy all upcoming calculations by saving outputs only with valid amount
                let amountValidOutputs = outputs.filter { output in
                    output.decimalAmount > 0
                }
                Logger.general.debug(category: "SyncWeb3Output", message: "Got \(outputs.count) outputs, \(amountValidOutputs) valid")
                Web3OutputDAO.shared.replaceUnspentOutputs(
                    walletID: walletID,
                    address: address.destination,
                    assetID: assetID,
                    outputs: amountValidOutputs
                )
            case let .failure(error):
                Logger.general.debug(category: "SyncWeb3Output", message: "\(error)")
            }
            self.finishJob()
        }
        return true
    }
    
}
