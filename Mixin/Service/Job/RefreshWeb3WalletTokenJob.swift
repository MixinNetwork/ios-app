import Foundation
import MixinServices

public final class RefreshWeb3WalletTokenJob: AsynchronousJob {
    
    private let walletID: String
    
    init(walletID: String) {
        self.walletID = walletID
        super.init()
    }
    
    override public func getJobId() -> String {
        "refresh-web3token-\(walletID)"
    }
    
    public override func execute() -> Bool {
        let walletID = walletID
        RouteAPI.assets(walletID: walletID, queue: .global()) { result in
            switch result {
            case let .success(tokens):
                Web3TokenDAO.shared.save(tokens: tokens)
            case let .failure(error):
                Logger.general.debug(category: "RefreshWeb3WalletToken", message: "\(error)")
                if !error.isTransportTimedOut {
                    reporter.report(error: error)
                }
            }
            self.finishJob()
        }
        return true
    }
    
}
