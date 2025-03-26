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
    
    init(destination: Payment.TransferDestination, transactions: [Transaction]) {
        self.destination = destination
        self.transactions = transactions
    }
    
    func start(pin: String) async throws {
        var hashes: [String] = []
        for (index, transaction) in transactions.enumerated() {
            let token = transaction.token
            let entry = transaction.entry
            Logger.general.info(category: "NonAtomicInvoicePayment", message: "Start txn \(index), \(entry.amount) \(token.symbol)")
            let spendingOutputs = try await collectOutputs(token: token, amount: entry.decimalAmount)
            Logger.general.info(category: "NonAtomicInvoicePayment", message: "Output collected")
            let reference = entry.references.map { reference in
                switch reference {
                case let .index(index):
                    hashes[index]
                case let .hash(hash):
                    hash
                }
            }.joined(separator: ",")
            Logger.general.info(category: "NonAtomicInvoicePayment", message: "Ref: \(reference)")
            let operation = TransferPaymentOperation.transfer(
                traceID: entry.traceID,
                spendingOutputs: spendingOutputs,
                destination: destination,
                token: token,
                amount: entry.decimalAmount,
                memo: entry.memo,
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
        repeat {
            let result = UTXOService.shared.collectUnspentOutputs(kernelAssetID: token.kernelAssetID, amount: amount)
            switch result {
            case .insufficientBalance:
                throw OutputCollectingError.insufficientBalance
            case .outputNotConfirmed:
                do {
                    let job = SyncOutputsJob()
                    ConcurrentJobQueue.shared.addJob(job: job)
                    Logger.general.info(category: "NonAtomicInvoicePayment", message: "Output not confirmed, sleep")
                    try await Task.sleep(nanoseconds: 10 * NSEC_PER_SEC)
                    Logger.general.info(category: "NonAtomicInvoicePayment", message: "Wake up")
                } catch {
                    throw OutputCollectingError.outputNotConfirmed
                }
                continue
            case .success(let outputCollection):
                return outputCollection
            case .maxSpendingCountExceeded:
                throw OutputCollectingError.maxSpendingCountExceeded
            }
        } while LoginManager.shared.isLoggedIn
        throw OutputCollectingError.loggedOut
    }
    
}
