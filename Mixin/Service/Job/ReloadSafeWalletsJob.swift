import UIKit
import MixinServices

final class ReloadSafeWalletsJob: AsynchronousJob {
    
    public static let safeWalletsDidUpdateNotification = Notification.Name("one.mixin.messenger.ReloadSafeWalletsJob.Update")
    public static let safeWalletsFailedToUpdateNotification = Notification.Name("one.mixin.messenger.ReloadSafeWalletsJob.Failed")
    
    override public func getJobId() -> String {
        "reload-safewallets"
    }
    
    public override func execute() -> Bool {
        Task.detached {
            do {
                let accounts = try await SafeAPI.userAccounts()
                let allAssetIDs = Set(accounts.flatMap(\.assets).map(\.mixinAssetID))
                var tokenTemplates = Web3TokenDAO.shared.tokens(assetIDs: allAssetIDs)
                let missingAssetIDs = allAssetIDs.subtracting(tokenTemplates.keys)
                if !missingAssetIDs.isEmpty {
                    let missingTokens = try await SafeAPI.assets(ids: missingAssetIDs)
                    for token in missingTokens {
                        tokenTemplates[token.assetID] = Web3Token(
                            walletID: "",
                            assetID: token.assetID,
                            chainID: token.chainID,
                            assetKey: token.assetKey,
                            kernelAssetID: token.kernelAssetID,
                            symbol: token.symbol,
                            name: token.name,
                            precision: token.precision,
                            iconURL: token.iconURL,
                            amount: "0",
                            usdPrice: token.usdPrice,
                            usdChange: token.usdChange,
                            level: Web3Reputation.Level.unknown.rawValue,
                        )
                    }
                }
                
                var wallets: [Web3Wallet] = []
                var tokens: [Web3Token] = []
                for account in accounts {
                    guard let wallet = Web3Wallet(account: account) else {
                        continue
                    }
                    let accountTokens = account.assets.compactMap { asset in
                        if let template = tokenTemplates[asset.mixinAssetID] {
                            Web3Token(
                                token: template,
                                replacingWalletID: account.accountID,
                                amount: asset.balance
                            )
                        } else {
                            nil
                        }
                    }
                    wallets.append(wallet)
                    tokens.append(contentsOf: accountTokens)
                }
                Web3WalletDAO.shared.replaceSafeWallets(wallets: wallets, tokens: tokens) {
                    NotificationCenter.default.post(
                        onMainThread: Self.safeWalletsDidUpdateNotification,
                        object: self,
                        userInfo: nil
                    )
                }
            } catch {
                let worthReporting = (error as? MixinAPIError)?.worthReporting ?? true
                if worthReporting {
                    reporter.report(error: error)
                }
                await MainActor.run {
                    NotificationCenter.default.post(
                        onMainThread: Self.safeWalletsFailedToUpdateNotification,
                        object: self,
                        userInfo: nil
                    )
                }
            }
        }
        return true
    }
    
}
