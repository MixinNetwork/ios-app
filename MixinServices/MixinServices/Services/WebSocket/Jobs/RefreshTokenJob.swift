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
                    Web3ChainDAO.shared.save([chain])
                }
                
                var pendingDeposits: [SafePendingDeposit] = []
                let entries = DepositEntryDAO.shared.entries(ofChainWith: token.chainID)
                for entry in entries {
                    let deposits = try await SafeAPI.deposits(assetID: token.assetID,
                                                              destination: entry.destination,
                                                              tag: entry.tag)
                    pendingDeposits.append(contentsOf: deposits)
                }
                SafeSnapshotDAO.shared.replacePendingSnapshots(assetID: assetID, pendingDeposits: pendingDeposits)
            } catch {
                let worthReporting = (error as? MixinAPIError)?.worthReporting ?? true
                if worthReporting {
                    reporter.report(error: error)
                }
            }
            self.finishJob()
        }
        return true
    }
    
}
