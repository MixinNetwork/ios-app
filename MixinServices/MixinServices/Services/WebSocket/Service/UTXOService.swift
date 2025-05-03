import Foundation
import GRDB

public final class UTXOService {
    
    public static let shared = UTXOService()
    
    public static let balanceDidUpdateNotification = Notification.Name("one.mixin.services.UTXOService.BalanceDidUpdate")
    public static let assetIDUserInfoKey = "aid"
    
    private let calculateBalancePageCount = 200
    private let maxSpendingOutputsCount = 256
    
    public func updateBalance(assetID: String, kernelAssetID: String, db: GRDB.Database) throws {
        let limit = self.calculateBalancePageCount
        
        var totalAmount: Decimal = 0
        var createdAt: String?
        var outputsCount = 0
        
        repeat {
            let outputs = try OutputDAO.shared.availableOutputs(
                asset: kernelAssetID,
                createdAfter: createdAt,
                limit: limit,
                db: db
            )
            Logger.general.debug(category: "UTXO", message: "Read \(outputs.count) outputs for amount calculation")
            for output in outputs {
                if let amount = output.decimalAmount {
                    totalAmount += amount
                } else {
                    Logger.general.error(category: "UTXO", message: "Invalid amount: \(output.amount), id: \(output.id)")
                }
            }
            createdAt = outputs.last?.createdAt
            outputsCount = outputs.count
        } while outputsCount >= limit
        Logger.general.debug(category: "UTXO", message: "Calculated \(totalAmount) for kernel asset: \(kernelAssetID)")
        
        let extra = TokenExtra(assetID: assetID,
                               kernelAssetID: kernelAssetID,
                               isHidden: false,
                               balance: TokenAmountFormatter.string(from: totalAmount),
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
        
        public init?(output: Output) {
            guard let amount = output.decimalAmount else {
                return nil
            }
            self.outputs = [output]
            self.lastOutput = output
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
    
    public func collectAvailableOutputs(kernelAssetID: String, amount: Decimal) -> CollectingResult {
        // Select 1 more output to see if there's more outputs available
        var availableOutputs = OutputDAO.shared.availableOutputs(asset: kernelAssetID, limit: maxSpendingOutputsCount + 1)
        let hasMoreAvailableOutput = availableOutputs.count > maxSpendingOutputsCount
        if hasMoreAvailableOutput {
            availableOutputs.removeLast()
        }
        
        var outputs: [Output] = []
        var outputsAmount: Decimal = 0
        outputs.reserveCapacity(availableOutputs.count)
        while outputsAmount < amount, !availableOutputs.isEmpty {
            let spending = availableOutputs.removeFirst()
            outputs.append(spending)
            if let spendingAmount = Decimal(string: spending.amount, locale: .enUSPOSIX) {
                outputsAmount += spendingAmount
            } else {
                Logger.general.error(category: "UTXOService", message: "Invalid amount: \(spending.amount)")
            }
        }
        if !outputs.isEmpty, outputsAmount >= amount {
            let collection = OutputCollection(outputs: outputs, amount: outputsAmount)
            return .success(collection)
        } else {
            if hasMoreAvailableOutput {
                return .maxSpendingCountExceeded
            } else {
                return .insufficientBalance
            }
        }
    }
    
    public func collectConsolidationOutputs(kernelAssetID: String) -> OutputCollection {
        let availableOutputs = OutputDAO.shared.availableOutputs(
            asset: kernelAssetID,
            limit: maxSpendingOutputsCount
        )
        
        var amount: Decimal = 0
        let outputs = availableOutputs.compactMap { output in
            if let outputAmount = output.decimalAmount {
                amount += outputAmount
                return output
            } else {
                Logger.general.error(category: "UTXOService", message: "Invalid amount: \(output.amount)")
                return nil
            }
        }
        
        return OutputCollection(outputs: outputs, amount: amount)
    }
    
}
