import Foundation
import MixinServices

public final class SaveWeb3TokenJob: AsynchronousJob {
    
    private let walletID: String
    private let assetID: String
    
    public init(walletID: String, assetID: String) {
        self.walletID = walletID
        self.assetID = assetID
    }
    
    override public func getJobId() -> String {
        "save-web3token-\(walletID)-\(assetID)"
    }
    
    public override func execute() -> Bool {
        Task.detached { [walletID, assetID] in
            do {
                let token = try await SafeAPI.assets(id: assetID)
                let amount = Web3TokenDAO.shared.amount(walletID: walletID, assetID: token.assetID)
                let web3Token = Web3Token(
                    walletID: walletID,
                    assetID: token.assetID,
                    chainID: token.chainID,
                    assetKey: token.assetKey,
                    kernelAssetID: token.kernelAssetID,
                    symbol: token.symbol,
                    name: token.name,
                    precision: token.precision,
                    iconURL: token.iconURL,
                    amount: amount ?? "0",
                    usdPrice: token.usdPrice,
                    usdChange: token.usdChange,
                    level: Web3Reputation.Level.unknown.rawValue,
                )
                if !MixinService.isStopProcessMessages {
                    Web3TokenDAO.shared.save(tokens: [web3Token], zeroOutOthers: false)
                }
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
