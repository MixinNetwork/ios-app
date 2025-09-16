import Foundation

public final class RefreshAllTokensJob: AsynchronousJob {
    
    override public func getJobId() -> String {
        "refresh-all-tokens"
    }
    
    public override func execute() -> Bool {
        Task {
            do {
                // Save default tokens, currently are native tokens of supported chains
                let tokens = try await SafeAPI.assets()
                if !MixinService.isStopProcessMessages {
                    TokenDAO.shared.save(assets: tokens)
                }
                
                // Save existed tokens, includes all tokens displayed in wallet view
                let ids = TokenDAO.shared.allAssetIDs()
                if !ids.isEmpty {
                    let tokens = try await SafeAPI.assets(ids: ids)
                    if !MixinService.isStopProcessMessages {
                        TokenDAO.shared.save(assets: tokens)
                    }
                }
                
                // Save chains
                let chains = try await NetworkAPI.chains()
                if !MixinService.isStopProcessMessages {
                    ChainDAO.shared.save(chains)
                    Web3ChainDAO.shared.save(chains)
                }
            } catch {
                let worthReporting = (error as? MixinAPIError)?.worthReporting ?? true
                if worthReporting {
                    reporter.report(error: error)
                }
                Logger.general.error(category: "RefreshAllTokensJob", message: error.localizedDescription)
            }
            ExternalAPI.fiats { (result) in
                switch result {
                case let .success(fiatMonies):
                    DispatchQueue.main.async {
                        Currency.updateRate(with: fiatMonies)
                    }
                case let .failure(error):
                    if error.worthReporting {
                        reporter.report(error: error)
                    }
                }
                self.finishJob()
            }
        }
        return true
    }
    
}
