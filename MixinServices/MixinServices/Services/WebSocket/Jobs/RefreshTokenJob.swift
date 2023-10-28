import Foundation

public class RefreshTokenJob: AsynchronousJob {
    
    private let assetID: String
    
    private var asset: Asset?
    
    public init(assetID: String) {
        self.assetID = assetID
    }
    
    override public func getJobId() -> String {
        return "refresh-token-" + assetID
    }
    
    public override func execute() -> Bool {
        Task {
            do {
                let token = try await SafeAPI.assets(id: assetID)
                if !MixinService.isStopProcessMessages {
                    TokenDAO.shared.save(assets: [token])
                }
                let chain = try await NetworkAPI.chain(id: token.chainId)
                if !MixinService.isStopProcessMessages {
                    ChainDAO.shared.insertOrUpdateChains([chain])
                }
                // Update fiats and snapshots?
                let entries = DepositEntryDAO.shared.entries(ofChainWith: token.chainId)
                for entry in entries {
                    let deposits = try await SafeAPI.pendingDeposits(assetID: token.assetID,
                                                                     destination: entry.destination,
                                                                     tag: entry.tag)
                    
                }
            } catch {
                reporter.report(error: error)
            }
            self.finishJob()
        }
        return true
    }
    
}
