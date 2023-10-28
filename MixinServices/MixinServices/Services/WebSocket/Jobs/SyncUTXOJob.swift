import Foundation

public final class SyncUTXOJob: AsynchronousJob {
    
    public override func getJobId() -> String {
        "sync-utxo"
    }
    
    public override func execute() -> Bool {
        let limit: Int = 200
        Task {
            guard let userID = LoginManager.shared.account?.userID else {
                Logger.general.error(category: "SyncUTXOJob", message: "No UID, give up")
                return
            }
            guard let data = userID.data(using: .utf8), let membersHash = SHA3_256.hash(data: data) else {
                Logger.general.error(category: "SyncUTXOJob", message: "Invalid UID: \(userID)")
                return
            }
            let members = membersHash.hexEncodedString()
            
            var assetIDs: [String: String] = [:] // Key is `kernel_asset_id`
            var outputs: [Output] = []
            
            var offset: String? = nil
            if let date = OutputDAO.shared.latestOutputCreatedAt() {
                offset = ISO8601CompatibleDateFormatter.string(from: date)
            } else {
                offset = nil
            }
            
            do {
                repeat {
                    outputs = try await SafeAPI.outputs(members: members,
                                                        threshold: 1,
                                                        offset: offset,
                                                        limit: limit,
                                                        user: userID)
                    guard let lastOutput = outputs.last else {
                        Logger.general.info(category: "SyncUTXOJob", message: "No new outputs")
                        break
                    }
                    
                    var balances: [String: Decimal] = [:] // Key is `kernel_asset_id`
                    var newTokens: [Token] = []
                    var newChains: [Chain] = []
                    
                    for output in outputs {
                        let kernelAssetID = output.asset
                        if assetIDs[kernelAssetID] == nil {
                            if let id = TokenDAO.shared.assetID(ofAssetWith: kernelAssetID) {
                                assetIDs[kernelAssetID] = id
                            } else {
                                let token = try await SafeAPI.assets(id: kernelAssetID)
                                newTokens.append(token)
                                if !ChainDAO.shared.chainExists(chainId: token.chainId) {
                                    let chain = try await NetworkAPI.chain(id: token.chainId)
                                    newChains.append(chain)
                                }
                                assetIDs[kernelAssetID] = token.assetID
                            }
                        }
                        if output.state == Output.State.unspent.rawValue {
                            let oldBalance = balances[kernelAssetID] ?? 0
                            if let newBalance = Decimal(string: output.amount, locale: .enUSPOSIX) {
                                balances[kernelAssetID] = oldBalance + newBalance
                            } else {
                                Logger.general.error(category: "SyncUTXOJob", message: "Invalid amount: \(output.amount)")
                            }
                        }
                    }
                    
                    let now = Date()
                    let extras = balances.compactMap { (kernelAssetID, balance) in
                        if let assetID = assetIDs[kernelAssetID] {
                            return TokenExtra(assetID: assetID,
                                              kernelAssetID: kernelAssetID,
                                              isHidden: nil,
                                              balance: Token.amountString(from: balance),
                                              updatedAt: now)
                        } else {
                            return nil
                        }
                    }
                    
                    OutputDAO.shared.save(outputs: outputs) { db in
                        try newTokens.save(db)
                        try newChains.save(db)
                        try extras.save(db)
                    }
                    Logger.general.info(category: "SyncUTXOJob", message: "Saved \(outputs.count) outputs")
                    offset = ISO8601CompatibleDateFormatter.string(from: lastOutput.createdAt)
                } while outputs.count >= limit && LoginManager.shared.isLoggedIn
                Logger.general.info(category: "SyncUTXOJob", message: "All UTXOs are synced")
            } catch {
                Logger.general.error(category: "SyncUTXOJob", message: "Failed to sync: \(error)")
            }
            await MainActor.run {
                finishJob()
            }
        }
        return true
    }
    
}
