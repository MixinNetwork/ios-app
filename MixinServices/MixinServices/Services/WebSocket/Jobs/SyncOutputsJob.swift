import UIKit
import GRDB

public final class SyncOutputsJob: AsynchronousJob {
    
    private let synchronizeOutputPageCount = 200
    
    public override func getJobId() -> String {
        "sync-outputs"
    }
    
    public override func execute() -> Bool {
        guard LoginManager.shared.isLoggedIn else {
            return false
        }
        guard ReachabilityManger.shared.isReachable else {
            return false
        }
        let limit = self.synchronizeOutputPageCount
        Task.detached {
            defer {
                self.finishJob()
            }
            guard let userID = LoginManager.shared.account?.userID else {
                Logger.general.error(category: "SyncOutputs", message: "No UID, give up")
                return
            }
            guard let data = userID.data(using: .utf8), let membersHash = SHA3_256.hash(data: data) else {
                Logger.general.error(category: "SyncOutputs", message: "Invalid UID: \(userID)")
                return
            }
            let members = membersHash.hexEncodedString()
            
            var assetIDs: [String: String] = [:] // Key is `kernel_asset_id`
            var outputs: [Output] = []
            
            var sequence: Int?
            if AppGroupUserDefaults.Wallet.areOutputSequencesReloaded {
                sequence = OutputDAO.shared.latestOutputSequence()
                Logger.general.info(category: "SyncOutputs", message: "Load from sequence: \(sequence)")
            } else {
                sequence = nil
                Logger.general.info(category: "SyncOutputs", message: "Reload for sequences")
            }
            do {
                repeat {
                    outputs = try await SafeAPI.outputs(members: members,
                                                        threshold: 1,
                                                        offset: sequence,
                                                        limit: limit,
                                                        state: Output.State.unspent.rawValue)
                    guard let lastOutput = outputs.last else {
                        Logger.general.info(category: "SyncOutputs", message: "No new outputs")
                        break
                    }
                    
                    var missingKernelAssetIDs: Set<String> = []
                    for kernelAssetID in outputs.map(\.asset) {
                        if assetIDs[kernelAssetID] == nil, !missingKernelAssetIDs.contains(kernelAssetID) {
                            if let id = TokenDAO.shared.assetID(ofAssetWith: kernelAssetID) {
                                assetIDs[kernelAssetID] = id
                            } else {
                                missingKernelAssetIDs.insert(kernelAssetID)
                            }
                        }
                    }
                    if !missingKernelAssetIDs.isEmpty {
                        let tokens = try await SafeAPI.assets(ids: missingKernelAssetIDs)
                        TokenDAO.shared.save(assets: tokens)
                        for token in tokens {
                            assetIDs[token.kernelAssetID] = token.assetID
                        }
                        for chainID in Set(tokens.map(\.chainID)) {
                            if !ChainDAO.shared.chainExists(chainId: chainID) {
                                let chain = try await NetworkAPI.chain(id: chainID)
                                ChainDAO.shared.save([chain])
                            }
                        }
                    }
                    
                    for hash in outputs.compactMap(\.inscriptionHash) {
                        let job = RefreshInscriptionJob(inscriptionHash: hash)
                        ConcurrentJobQueue.shared.addJob(job: job)
                    }
                    
                    OutputDAO.shared.insertOrReplace(outputs: outputs, onConflict: .replaceIfNotSigned) { db in
                        let kernelAssetIDs = Set(outputs.map(\.asset))
                        for kernelAssetID in kernelAssetIDs {
                            if let assetID = assetIDs[kernelAssetID] {
                                try UTXOService.shared.updateBalance(assetID: assetID,
                                                                     kernelAssetID: kernelAssetID,
                                                                     db: db)
                            } else {
                                Logger.general.error(category: "SyncOutputs", message: "No asset ID: \(kernelAssetID)")
                            }
                        }
                    }
                    Logger.general.info(category: "SyncOutputs", message: "Saved \(outputs.count) outputs")
                    sequence = lastOutput.sequence
                } while outputs.count >= limit && LoginManager.shared.isLoggedIn
                AppGroupUserDefaults.Wallet.areOutputSequencesReloaded = true
                Logger.general.info(category: "SyncOutputs", message: "All outputs are synced")
            } catch MixinAPIResponseError.unauthorized {
                Logger.general.error(category: "SyncOutputs", message: "Unauthorized, stop syncing")
            } catch {
                Logger.general.error(category: "SyncOutputs", message: "Failed to sync: \(error)")
            }
        }
        return true
    }
    
}
