import Foundation
import GRDB

public final class UTXOService {
    
    public static let shared = UTXOService()
    
    public static let balanceDidUpdateNotification = Notification.Name("one.mixin.services.UTXOService.BalanceDidUpdate")
    public static let assetIDUserInfoKey = "aid"
    
    private let synchronizeOutputPageCount = 200
    private let calculateBalancePageCount = 200
    private let maxSpendingOutputsCount = 256
    
    public func synchronize() {
        guard LoginManager.shared.isLoggedIn else {
            return
        }
        guard ReachabilityManger.shared.isReachable else {
            DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: synchronize)
            return
        }
        let limit = self.synchronizeOutputPageCount
        Task.detached {
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
                                                        state: Output.State.unspent.rawValue)
                    guard let lastOutput = outputs.last else {
                        Logger.general.info(category: "UTXO", message: "No new outputs")
                        break
                    }
                    
                    var missingKernelAssetIDs: Set<String> = []
                    for output in outputs {
                        let kernelAssetID = output.asset
                        if assetIDs[kernelAssetID] == nil, !missingKernelAssetIDs.contains(kernelAssetID) {
                            if let id = TokenDAO.shared.assetID(ofAssetWith: kernelAssetID) {
                                assetIDs[kernelAssetID] = id
                            } else {
                                missingKernelAssetIDs.insert(kernelAssetID)
                            }
                        }
                        if let inscriptionHash = output.inscriptionHash, !inscriptionHash.isEmpty {
                            let inscription = try await InscriptionAPI.inscription(inscriptionHash: inscriptionHash)
                            InscriptionDAO.shared.save(inscription: inscription)
                            if !InscriptionDAO.shared.collectionExists(collectionHash: inscription.collectionHash) {
                                let collection = try await InscriptionAPI.collection(collectionHash: inscription.collectionHash)
                                InscriptionDAO.shared.save(collection: collection)
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
                    
                    OutputDAO.shared.insertOrIgnore(outputs: outputs) { db in
                        let kernelAssetIDs = Set(outputs.map(\.asset))
                        for kernelAssetID in kernelAssetIDs {
                            if let assetID = assetIDs[kernelAssetID] {
                                try self.updateBalance(assetID: assetID, kernelAssetID: kernelAssetID, db: db)
                            } else {
                                Logger.general.error(category: "UTXO", message: "No asset ID: \(kernelAssetID)")
                            }
                        }
                    }
                    Logger.general.info(category: "UTXO", message: "Saved \(outputs.count) outputs")
                    sequence = lastOutput.sequence
                } while outputs.count >= limit && LoginManager.shared.isLoggedIn
                Logger.general.info(category: "UTXO", message: "All UTXOs are synced")
            } catch MixinAPIResponseError.unauthorized {
                Logger.general.error(category: "UTXO", message: "Unauthorized, stop syncing")
            } catch {
                Logger.general.error(category: "UTXO", message: "Failed to sync: \(error)")
                DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: self.synchronize)
            }
        }
    }
    
    @MainActor 
    public func synchronize(
        assetID: String,
        kernelAssetID: String,
        completion: @MainActor @escaping (Error?) -> Void
    ) {
        enum SyncError: Error {
            case badNetwork
            case encodeMembers
        }
        
        guard LoginManager.shared.isLoggedIn else {
            return
        }
        guard ReachabilityManger.shared.isReachable else {
            completion(SyncError.badNetwork)
            return
        }
        let limit = self.synchronizeOutputPageCount
        Task {
            guard let userID = LoginManager.shared.account?.userID else {
                return
            }
            guard let data = userID.data(using: .utf8), let membersHash = SHA3_256.hash(data: data) else {
                await MainActor.run {
                    completion(SyncError.encodeMembers)
                }
                return
            }
            let members = membersHash.hexEncodedString()
            
            var outputs: [Output] = []
            var sequence = OutputDAO.shared.latestOutputSequence(asset: kernelAssetID)
            
            do {
                repeat {
                    outputs = try await SafeAPI.outputs(members: members,
                                                        threshold: 1,
                                                        offset: sequence,
                                                        limit: limit,
                                                        state: Output.State.unspent.rawValue,
                                                        asset: kernelAssetID)
                    guard let lastOutput = outputs.last else {
                        break
                    }
                    OutputDAO.shared.insertOrIgnore(outputs: outputs) { db in
                        try self.updateBalance(assetID: assetID, kernelAssetID: kernelAssetID, db: db)
                    }
                    sequence = lastOutput.sequence
                } while outputs.count >= limit && LoginManager.shared.isLoggedIn
            } catch MixinAPIResponseError.unauthorized {
                return
            } catch {
                await MainActor.run {
                    completion(error)
                }
            }
            await MainActor.run {
                completion(nil)
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
                               isHidden: false,
                               balance: Token.amountString(from: totalAmount),
                               updatedAt: Date().toUTCString())
        try TokenExtraDAO.shared.insertOrUpdateBalance(extra: extra, into: db) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.balanceDidUpdateNotification,
                                                object: self,
                                                userInfo: [Self.assetIDUserInfoKey: assetID])
            }
        }
    }
    
}

extension UTXOService {
    
    public struct OutputCollection: CustomDebugStringConvertible {
        
        private struct Input: Encodable {
            let index: Int
            let hash: String
            let amount: String
        }
        
        public let outputs: [Output]
        public let lastOutput: Output
        public let amount: Decimal
        
        public var debugDescription: String {
            "<OutputCollection outputs: \(outputs.count), amount: \(amount)>"
        }
        
        init(outputs: [Output], amount: Decimal) {
            self.outputs = outputs
            self.lastOutput = outputs.last!
            self.amount = amount
        }
        
        public func encodeAsInputData() throws -> Data {
            let inputs = outputs.map { (utxo) in
                Input(index: utxo.outputIndex, hash: utxo.transactionHash, amount: utxo.amount)
            }
            return try JSONEncoder.default.encode(inputs)
        }
        
        public func encodedKeys() throws -> String? {
            let data = try JSONEncoder.default.encode(outputs.map(\.keys))
            return String(data: data, encoding: .utf8)
        }
        
    }
    
    public enum CollectingResult {
        case success(OutputCollection)
        case insufficientBalance
        case maxSpendingCountExceeded
    }
    
    public enum InscriptionCollectingResult {
        case success(OutputCollection)
        case missingOutput
        case invalidAmount
    }
    
    public func collectUnspentOutputs(kernelAssetID: String, amount: Decimal) -> CollectingResult {
        // Select 1 more output to see if there's more outputs unspent
        var unspentOutputs = OutputDAO.shared.unspentOutputs(asset: kernelAssetID, limit: maxSpendingOutputsCount + 1)
        let hasMoreUnspentOutput = unspentOutputs.count > maxSpendingOutputsCount
        if hasMoreUnspentOutput {
            unspentOutputs.removeLast()
        }
        
        var outputs: [Output] = []
        var outputsAmount: Decimal = 0
        outputs.reserveCapacity(unspentOutputs.count)
        while outputsAmount < amount, !unspentOutputs.isEmpty {
            let spending = unspentOutputs.removeFirst()
            outputs.append(spending)
            if let spendingAmount = Decimal(string: spending.amount, locale: .enUSPOSIX) {
                outputsAmount += spendingAmount
            } else {
                Logger.general.error(category: "UTXOService", message: "Invalid utxo.amount: \(spending.amount)")
            }
        }
        if !outputs.isEmpty, outputsAmount >= amount {
            let collection = OutputCollection(outputs: outputs, amount: outputsAmount)
            return .success(collection)
        } else {
            if hasMoreUnspentOutput {
                return .maxSpendingCountExceeded
            } else {
                return .insufficientBalance
            }
        }
    }
    
    public func collectConsolidationOutputs(kernelAssetID: String) -> OutputCollection {
        let unspentOutputs = OutputDAO.shared.unspentOutputs(asset: kernelAssetID, limit: maxSpendingOutputsCount)
        
        var amount: Decimal = 0
        let outputs = unspentOutputs.compactMap { output in
            if let outputAmount = Decimal(string: output.amount, locale: .enUSPOSIX) {
                amount += outputAmount
                return output
            } else {
                Logger.general.error(category: "UTXOService", message: "Invalid utxo.amount: \(output.amount)")
                return nil
            }
        }
        
        return OutputCollection(outputs: outputs, amount: amount)
    }
    
    public func inscriptionOutput(hash: String) -> InscriptionCollectingResult {
        guard let output = OutputDAO.shared.getOutput(inscriptionHash: hash) else {
            return .missingOutput
        }
        guard let amount = Decimal(string: output.amount, locale: .enUSPOSIX) else {
            return .invalidAmount
        }
        let collection = OutputCollection(outputs: [output], amount: amount)
        return .success(collection)
    }
    
}
