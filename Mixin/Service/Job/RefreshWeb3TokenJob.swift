import Foundation
import MixinServices

public final class RefreshWeb3TokenJob: AsynchronousJob {
    
    private let token: Web3Token
    
    private var walletID: String {
        token.walletID
    }
    
    private var assetID: String {
        token.assetID
    }
    
    init(token: Web3Token) {
        self.token = token
        super.init()
    }
    
    override public func getJobId() -> String {
        "refresh-web3token-\(walletID)-\(assetID)"
    }
    
    public override func execute() -> Bool {
        let address = Web3AddressDAO.shared.address(walletID: walletID, chainID: token.chainID)
        guard let address = address?.destination else {
            finishJob()
            return true
        }
        RouteAPI.asset(assetID: assetID, address: address, queue: .global()) { result in
            switch result {
            case let .success(token):
                Web3TokenDAO.shared.save(
                    tokens: [token],
                    outputBasedAssetIDs: [AssetID.btc],
                    zeroOutOthers: false
                )
            case let .failure(error):
                Logger.general.debug(category: "RefreshWeb3Token", message: "\(error)")
                if error.worthReporting {
                    reporter.report(error: error)
                }
            }
            self.finishJob()
        }
        return true
    }
    
}
