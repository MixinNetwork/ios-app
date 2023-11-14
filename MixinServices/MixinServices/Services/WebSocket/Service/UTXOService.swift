import Foundation
import GRDB

public final class UTXOService {
    
    public static let shared = UTXOService()
    
    public static let balanceDidUpdateNotification = Notification.Name("one.mixin.services.UTXOService.BalanceDidUpdate")
    
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
                                                        state: Output.State.unspent.rawValue)
                    guard let lastOutput = outputs.last else {
                        Logger.general.info(category: "UTXO", message: "No new outputs")
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
                               isHidden: false,
                               balance: Token.amountString(from: totalAmount),
                               updatedAt: Date().toUTCString())
        try TokenExtraDAO.shared.insertOrUpdateBalance(extra: extra, into: db) {
            NotificationCenter.default.post(onMainThread: Self.balanceDidUpdateNotification, object: self)
        }
    }
    
}

extension UTXOService {
    
    public enum CollectingError: Error {
        case insufficientBalance
        case maxSpendingCountExceeded
    }
    
    public struct OutputCollection {
        
        private struct Input: Encodable {
            let index: Int
            let hash: String
            let amount: String
        }
        
        public let outputs: [Output]
        public let lastOutput: Output
        
        init(outputs: [Output]) {
            self.outputs = outputs
            self.lastOutput = outputs.last!
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
    
    public func collectUnspentOutputs(kernelAssetID: String, amount: Decimal) throws -> OutputCollection {
        // Select 1 more output to see if there's more outputs unspent
        var unspentOutputs = OutputDAO.shared.unspentOutputs(asset: kernelAssetID, limit: maxSpendingOutputsCount + 1)
        let hasMoreUnspentOutput = unspentOutputs.count > maxSpendingOutputsCount
        if hasMoreUnspentOutput {
            unspentOutputs.removeLast()
        }
        
        var outputs: [Output] = []
        var outputsAmount: Decimal = 0
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
            return OutputCollection(outputs: outputs)
        } else {
            if hasMoreUnspentOutput {
                throw CollectingError.maxSpendingCountExceeded
            } else {
                throw CollectingError.insufficientBalance
            }
        }
    }
    
}
