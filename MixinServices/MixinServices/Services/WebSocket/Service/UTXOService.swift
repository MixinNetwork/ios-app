import Foundation
import GRDB

public final class UTXOService {
    
    public static let shared = UTXOService()
    
    private let synchronizeOutputPageCount = 200
    private let calculateBalancePageCount = 200
    
    public func synchronize() {
        guard LoginManager.shared.isLoggedIn else {
            return
        }
        guard ReachabilityManger.shared.isReachable else {
            DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: synchronize)
            return
        }
        let limit = self.synchronizeOutputPageCount
        Task {
            guard let userID = LoginManager.shared.account?.userID else {
                Logger.general.error(category: "UTXO", message: "No UID, give up")
                return
            }
            guard let data = userID.data(using: .utf8), let membersHash = SHA3_256.hash(data: data) else {
                Logger.general.error(category: "UTXO", message: "Invalid UID: \(userID)")
                return
            }
            let members = membersHash.hexEncodedString()
            
            var assetIDs: [String: String] = [:] // Key is `kernel_asset_id`
            var outputs: [Output] = []
            
            var sequence = OutputDAO.shared.latestOutputSequence()
            Logger.general.debug(category: "UTXO", message: "Sync from: \(sequence)")
            
            do {
                repeat {
                    outputs = try await SafeAPI.outputs(members: members,
                                                        threshold: 1,
                                                        offset: sequence,
                                                        limit: limit,
                                                        state: Output.State.unspent.rawValue,
                                                        user: userID)
                    guard let lastOutput = outputs.last else {
                        Logger.general.info(category: "UTXO", message: "No new outputs")
                        break
                    }
                    
                    for output in outputs {
                        let kernelAssetID = output.asset
                        if assetIDs[kernelAssetID] == nil {
                            if let id = TokenDAO.shared.assetID(ofAssetWith: kernelAssetID) {
                                assetIDs[kernelAssetID] = id
                            } else {
                                do {
                                    let token = try await SafeAPI.assets(id: kernelAssetID)
                                    TokenDAO.shared.save(assets: [token])
                                    if !ChainDAO.shared.chainExists(chainId: token.chainId) {
                                        let chain = try await NetworkAPI.chain(id: token.chainId)
                                        ChainDAO.shared.save([chain])
                                    }
                                    assetIDs[kernelAssetID] = token.assetID
                                } catch MixinAPIError.notFound {
                                    // Tokens and chains may be absent. Ignore the output
                                } catch {
                                    throw error
                                }
                            }
                        }
                    }
                    
                    OutputDAO.shared.insertOrIgnore(outputs: outputs) { db in
                        for output in outputs {
                            if let assetID = assetIDs[output.asset] {
                                try self.updateBalance(assetID: assetID, kernelAssetID: output.asset, db: db)
                            } else {
                                Logger.general.error(category: "UTXO", message: "No asset ID: \(output.asset)")
                            }
                        }
                    }
                    Logger.general.info(category: "UTXO", message: "Saved \(outputs.count) outputs")
                    sequence = lastOutput.sequence
                } while outputs.count >= limit && LoginManager.shared.isLoggedIn
                Logger.general.info(category: "UTXO", message: "All UTXOs are synced")
            } catch MixinAPIError.unauthorized {
                Logger.general.error(category: "UTXO", message: "Unauthorized, stop syncing")
            } catch {
                Logger.general.error(category: "UTXO", message: "Failed to sync: \(error)")
                DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: synchronize)
            }
        }
    }
    
    public func updateBalance(assetID: String, kernelAssetID: String, db: GRDB.Database) throws {
        let limit = self.calculateBalancePageCount
        
        var totalAmount: Decimal = 0
        var sequence: Int?
        var outputsCount = 0
        
        repeat {
            let outputs = try OutputDAO.shared.unspentOutputs(asset: kernelAssetID, after: sequence, limit: limit, db: db)
            Logger.general.debug(category: "UTXO", message: "Read \(outputs.count) outputs for amount calculation")
            for output in outputs {
                if let amount = Decimal(string: output.amount, locale: .enUSPOSIX) {
                    totalAmount += amount
                } else {
                    Logger.general.error(category: "UTXO", message: "Invalid amount: \(output.amount), id: \(output.id)")
                }
            }
            sequence = outputs.last?.sequence
            outputsCount = outputs.count
        } while outputsCount >= limit
        Logger.general.debug(category: "UTXO", message: "Calculated \(totalAmount) for kernel asset: \(kernelAssetID)")
        
        let extra = TokenExtra(assetID: assetID,
                               kernelAssetID: kernelAssetID,
                               isHidden: nil,
                               balance: Token.amountString(from: totalAmount),
                               updatedAt: Date().toUTCString())
        try TokenExtraDAO.shared.insertOrUpdateBalance(extra: extra, into: db)
    }
    
}
