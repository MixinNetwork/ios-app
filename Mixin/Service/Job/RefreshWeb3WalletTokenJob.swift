import Foundation
import MixinServices

public final class RefreshWeb3WalletTokenJob: AsynchronousJob {
    
    private let walletID: String
    
    init(walletID: String) {
        self.walletID = walletID
        super.init()
    }
    
    static func jobID(walletID: String) -> String {
        "refresh-web3token-\(walletID)"
    }
    
    override public func getJobId() -> String {
        Self.jobID(walletID: walletID)
    }
    
    public override func execute() -> Bool {
        let walletID = walletID
        RouteAPI.assets(walletID: walletID, queue: .global()) { result in
            switch result {
            case let .success(tokens):
                guard !self.isCancelled else {
                    return
                }
                Web3TokenDAO.shared.save(tokens: tokens, zeroOutOthers: true)
            case let .failure(error):
                Logger.general.debug(category: "RefreshWeb3WalletToken", message: "\(error)")
                if error.worthReporting {
                    reporter.report(error: error)
                }
            }
            self.finishJob()
        }
        return true
    }
    
}
