import Foundation
import MixinServices
import TIP

final class NonAtomicInvoicePaymentOperation: InvoicePaymentOperation {
    
    enum OutputCollectingError: Error {
        case insufficientBalance
        case outputNotConfirmed
        case maxSpendingCountExceeded
        case loggedOut
    }
    
    enum OperationError: Error {
        case decodeExtra
        case missingHash
    }
    
    class Transaction: InvoicePaymentOperationTransaction {
        
        let entry: Invoice.Entry
        let token: MixinTokenItem
        
        init(entry: Invoice.Entry, token: MixinTokenItem) {
            self.entry = entry
            self.token = token
        }
        
    }
    
    let destination: Payment.TransferDestination
    let transactions: [Transaction]
    let paidEntriesHash: [String]
    
    init(
        destination: Payment.TransferDestination,
        transactions: [Transaction],
        paidEntriesHash: [String]
    ) {
        self.destination = destination
        self.transactions = transactions
        self.paidEntriesHash = paidEntriesHash
    }
    
    func start(pin: String) async throws {
        // In case of decoding failure, do it earlier to avoid partial success
        let extras: [TransferPaymentOperation.Extra] = try transactions.map { transaction in
            let entry = transaction.entry
            if entry.isStorage {
                return .hexEncoded(entry.extra.hexEncodedString())
            } else {
                if let extra = String(data: entry.extra, encoding: .utf8) {
                    return .plain(extra)
                } else {
                    throw OperationError.decodeExtra
                }
            }
        }
        
        var hashes = paidEntriesHash
        for (index, transaction) in transactions.enumerated() {
            guard index > paidEntriesHash.count - 1 else {
                Logger.general.info(category: "NonAtomicInvoicePayment", message: "Skip txn \(index), hash: \(hashes[index])")
                continue
            }
            let token = transaction.token
            let entry = transaction.entry
            Logger.general.info(category: "NonAtomicInvoicePayment", message: "Start txn \(index), \(entry.amount) \(token.symbol)")
            let spendingOutputs = try await collectOutputs(token: token, amount: entry.decimalAmount)
            Logger.general.info(category: "NonAtomicInvoicePayment", message: "Output collected, states: \(spendingOutputs.outputs.map(\.state))")
            let reference = entry.references.map { reference in
                switch reference {
                case let .index(index):
                    hashes[index]
                case let .hash(hash):
                    hash
                }
            }.joined(separator: ",")
            Logger.general.info(category: "NonAtomicInvoicePayment", message: "Ref: \(reference)")
            let destination = entry.isStorage ? .storageFeeReceiver : self.destination
            let operation: TransferPaymentOperation = .transfer(
                traceID: entry.traceID,
                spendingOutputs: spendingOutputs,
                destination: destination,
                token: token,
                amount: entry.decimalAmount,
                extra: extras[index],
                reference: reference
            )
            Logger.general.info(category: "NonAtomicInvoicePayment", message: "Start sub-op")
            try await operation.start(pin: pin)
            if let hash = operation.kernelTransactionHash {
                Logger.general.info(category: "NonAtomicInvoicePayment", message: "Append hash: \(hash)")
                hashes.append(hash)
            } else {
                Logger.general.info(category: "NonAtomicInvoicePayment", message: "Missing hash")
                throw OperationError.missingHash
            }
        }
    }
    
    private func collectOutputs(
        token: MixinTokenItem,
        amount: Decimal
    ) async throws -> UTXOService.OutputCollection {
        let result = UTXOService.shared.collectAvailableOutputs(kernelAssetID: token.kernelAssetID, amount: amount)
        switch result {
        case .insufficientBalance:
            throw OutputCollectingError.insufficientBalance
        case .outputNotConfirmed:
            // Not expected to happen
            throw OutputCollectingError.outputNotConfirmed
        case .success(let outputCollection):
            return outputCollection
        case .maxSpendingCountExceeded:
            throw OutputCollectingError.maxSpendingCountExceeded
        }
    }
    
}
