import Foundation

public final class RefreshAllTokensJob: AsynchronousJob {
    
    override public func getJobId() -> String {
        "refresh-all-tokens"
    }
    
    public override func execute() -> Bool {
        Task {
            do {
                let tokens = try await SafeAPI.assets()
                if !MixinService.isStopProcessMessages {
                    TokenDAO.shared.save(assets: tokens)
                }
                let chains = try await NetworkAPI.chains()
                if !MixinService.isStopProcessMessages {
                    ChainDAO.shared.save(chains)
                }
            } catch {
                reporter.report(error: error)
                Logger.general.error(category: "RefreshAllTokensJob", message: error.localizedDescription)
            }
            AssetAPI.fiats { (result) in
                switch result {
                case let .success(fiatMonies):
                    DispatchQueue.main.async {
                        Currency.updateRate(with: fiatMonies)
                    }
                case let .failure(error):
                    reporter.report(error: error)
                }
                self.finishJob()
            }
        }
        return true
    }
    
}
