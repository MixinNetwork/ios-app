import Foundation

public final class RefreshTokenJob: AsynchronousJob {
    
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
                let chain = try await NetworkAPI.chain(id: token.chainID)
                if !MixinService.isStopProcessMessages {
                    ChainDAO.shared.save([chain])
                }
                let entries = DepositEntryDAO.shared.entries(ofChainWith: token.chainID)
                for entry in entries {
                    let deposits = try await SafeAPI.pendingDeposits(assetID: token.assetID,
                                                                     destination: entry.destination,
                                                                     tag: entry.tag)
                    SafeSnapshotDAO.shared.saveSnapshots(with: assetID, pendingDeposits: deposits)
                }
                // Update fiats and snapshots?
            } catch {
                reporter.report(error: error)
            }
            self.finishJob()
        }
        return true
    }
    
}