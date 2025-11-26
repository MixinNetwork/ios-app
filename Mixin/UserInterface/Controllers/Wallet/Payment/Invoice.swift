import Foundation
import CryptoKit
import MixinServices

struct Invoice {
    
    enum Reference {
        case hash(String)
        case index(Int)
    }
    
    struct Entry {
        let traceID: String
        let assetID: String
        let amount: String
        let decimalAmount: Decimal
        let extra: Data
        let references: [Reference]
        let isStorage: Bool
    }
    
    let recipient: MIXAddress
    let entries: [Entry]
    let sendingSameTokenMultipleTimes: Bool
    
}

extension Invoice {
    
    private enum MaxExtraSize {
        static let general = 256 - 1
        static let storage = 4 * bytesPerMegaByte - 1
    }
    
    private enum Storage {
        
        static let step: Int = 1024
        static let stepPrice: Decimal = 0.0001
        
        static func fee(byteCount: Int) -> Decimal {
            Decimal(byteCount / step + 1) * stepPrice
        }
        
    }
    
    private enum InitError: Error {
        case invalidString
        case base64Decoding
        case invalidLength(Int)
        case invalidChecksum
        case unknownVersion
        case invalidRecipient
        case invalidEntriesCount
        case invalidEntry
        case invalidReferenceType
        case invalidHashReference
        case invalidIndexReference
        case sha3
        case emptyEntries
    }
    
    private enum CheckingError: Error, LocalizedError {
        
        case alreadyPaid
        case entryPaidAfterUnpaid
        case entryPaidIntermediately
        
        var errorDescription: String? {
            switch self {
            case .alreadyPaid:
                R.string.localizable.pay_paid()
            case .entryPaidAfterUnpaid:
                "Entry paid after unpaid"
            case .entryPaidIntermediately:
                "Entry paid intermediately"
            }
        }
        
    }
    
    private class DataReader {
        
        private let data: Data
        
        private var location: Data.Index
        
        init(data: Data) {
            self.data = data
            self.location = data.startIndex
        }
        
        func readUInt8() -> UInt8? {
            guard location != data.endIndex else {
                return nil
            }
            let location = self.location
            self.location = location.advanced(by: 1)
            return data[location]
        }
        
        func readUInt16() -> UInt16? {
            let nextLocation = location.advanced(by: 2)
            guard nextLocation <= data.endIndex else {
                return nil
            }
            let low = data[location]
            let high = data[location.advanced(by: 1)]
            self.location = nextLocation
            return UInt16(data: [low, high], endianess: .big)
        }
        
        func readBytes(count: Int) -> Data? {
            if count == 0 {
                return Data()
            }
            let nextLocation = location.advanced(by: count)
            guard nextLocation <= data.endIndex else {
                return nil
            }
            let bytes = data[location..<nextLocation]
            self.location = nextLocation
            return bytes
        }
        
        func readUUID() -> String? {
            if let data = readBytes(count: UUID.dataCount) {
                UUID(data: data).uuidString.lowercased()
            } else {
                nil
            }
        }
        
    }
    
    private static let version: UInt8 = 0
    
    init(string: String) throws {
        let prefix = "MIN"
        
        guard string.hasPrefix(prefix) else {
            throw InitError.invalidString
        }
        guard let data = Data(base64URLEncoded: string.suffix(string.count - prefix.count)) else {
            throw InitError.base64Decoding
        }
        guard data.count >= 3 + 23 + 1 else {
            throw InitError.invalidLength(data.count)
        }
        
        let payload = data.prefix(data.count - 4)
        let expectedChecksum = data.suffix(4)
        let checksum = try {
            let data = prefix.data(using: .utf8)! + payload
            guard let digest = SHA3_256.hash(data: data) else {
                throw InitError.sha3
            }
            return digest.prefix(4)
        }()
        guard expectedChecksum == checksum else {
            throw InitError.invalidChecksum
        }
        
        let reader = DataReader(data: payload)
        guard reader.readUInt8() == Self.version else {
            throw InitError.unknownVersion
        }
        
        guard
            let recipientLength = reader.readUInt16(),
            let recipientData = reader.readBytes(count: Int(recipientLength)),
            let recipient = MIXAddress(data: recipientData)
        else {
            throw InitError.invalidRecipient
        }
        
        guard let entriesCount = reader.readUInt8() else {
            throw InitError.invalidEntriesCount
        }
        var entries: [Entry] = []
        entries.reserveCapacity(Int(entriesCount))
        for _ in 0..<entriesCount {
            guard
                let traceID = reader.readUUID(),
                let assetID = reader.readUUID(),
                let amountLength = reader.readUInt8(),
                let amountData = reader.readBytes(count: Int(amountLength)),
                let amount = String(data: amountData, encoding: .utf8),
                let decimalAmount = Decimal(string: amount, locale: .enUSPOSIX),
                let extraLength = reader.readUInt16(),
                let extra = reader.readBytes(count: Int(extraLength)),
                extra.count <= MaxExtraSize.storage,
                let referencesCount = reader.readUInt8()
            else {
                throw InitError.invalidEntry
            }
            
            let references: [Reference] = try (0..<referencesCount).map { _ in
                switch reader.readUInt8() {
                case 0:
                    if let hash = reader.readBytes(count: 32) {
                        return .hash(hash.hexEncodedString())
                    } else {
                        throw InitError.invalidHashReference
                    }
                case 1:
                    if let index = reader.readUInt8(), index < entries.count {
                        return .index(Int(index))
                    } else {
                        throw InitError.invalidIndexReference
                    }
                default:
                    throw InitError.invalidReferenceType
                }
            }
            
            let isStorage = assetID == AssetID.xin
            && !extra.isEmpty
            && extra.count > MaxExtraSize.general
            && Storage.fee(byteCount: extra.count) == decimalAmount
            
            let entry = Entry(
                traceID: traceID,
                assetID: assetID,
                amount: amount,
                decimalAmount: decimalAmount,
                extra: extra,
                references: references,
                isStorage: isStorage
            )
            entries.append(entry)
        }
        if entries.isEmpty {
            throw InitError.emptyEntries
        }
        
        var assetIDs: Set<String> = []
        var sendingSameTokenMultipleTimes = false
        for entry in entries {
            let (inserted, _) = assetIDs.insert(entry.assetID)
            if !inserted {
                sendingSameTokenMultipleTimes = true
                break
            }
        }
        
        self.recipient = recipient
        self.entries = entries
        self.sendingSameTokenMultipleTimes = sendingSameTokenMultipleTimes
    }
    
}

extension Invoice {
    
    enum BalanceSufficiency {
        case sufficient
        case insufficient(BalanceRequirement)
        case failure(Error)
    }
    
    func checkBalanceSufficiency(tokens: [String: MixinTokenItem]) -> BalanceSufficiency {
        var requiredAmounts: [String: Decimal] = [:] // Key is asset id
        for entry in entries {
            let amount = requiredAmounts[entry.assetID] ?? 0
            requiredAmounts[entry.assetID] = entry.decimalAmount + amount
        }
        
        var requirements: [BalanceRequirement] = []
        for (assetID, amount) in requiredAmounts {
            if let token = tokens[assetID] {
                let requirement = BalanceRequirement(token: token, amount: amount)
                requirements.append(requirement)
            } else {
                do {
                    let token = try SafeAPI.asset(id: assetID).get()
                    let chain: Chain
                    if let localChain = ChainDAO.shared.chain(chainId: token.chainID) {
                        chain = localChain
                    } else {
                        chain = try NetworkAPI.chain(id: token.chainID).get()
                        ChainDAO.shared.save([chain])
                        Web3ChainDAO.shared.save([chain])
                    }
                    let item = MixinTokenItem(token: token, balance: "0", isHidden: false, chain: chain)
                    let requirement = BalanceRequirement(token: item, amount: amount)
                    return .insufficient(requirement)
                } catch {
                    return .failure(error)
                }
            }
        }
        if let requirement = requirements.first(where: { !$0.isSufficient }) {
            return .insufficient(requirement)
        } else {
            return .sufficient
        }
    }
    
}

extension Invoice: PaymentPreconditionChecker {
    
    private struct OutputsReadyPrecondition: PaymentPrecondition {
        
        let entries: [Entry]
        let tokens: [String: MixinTokenItem] // Key is asset id
        
        func check() async -> PaymentPreconditionCheckingResult {
            var amounts: [String: Decimal] = [:] // Key is kernel asset id
            for entry in entries {
                guard let kernelAssetID = tokens[entry.assetID]?.kernelAssetID else {
                    return .failed(.description(R.string.localizable.insufficient_balance()))
                }
                let amount = amounts[kernelAssetID] ?? 0
                amounts[kernelAssetID] = amount + entry.decimalAmount
            }
            for token in tokens.values {
                guard let amount = amounts[token.kernelAssetID] else {
                    continue
                }
                let result = UTXOService.shared.collectAvailableOutputs(
                    kernelAssetID: token.kernelAssetID,
                    amount: amount
                )
                switch result {
                case .success:
                    Logger.general.info(category: "Invoice", message: "Outputs ready for \(token.symbol)")
                case .insufficientBalance:
                    Logger.general.info(category: "Invoice", message: "Insufficient balance for \(token.symbol)")
                    return .failed(.description(R.string.localizable.insufficient_balance()))
                case .maxSpendingCountExceeded:
                    Logger.general.info(category: "Invoice", message: "\(token.symbol) requires consolidation")
                    let consolidationResult = await withCheckedContinuation { continuation in
                        DispatchQueue.main.async {
                            let consolidation = ConsolidateOutputsViewController(token: token)
                            consolidation.onCompletion = { result in
                                continuation.resume(with: .success(result))
                            }
                            let auth = AuthenticationViewController(intent: consolidation)
                            UIApplication.homeContainerViewController?.present(auth, animated: true)
                        }
                    }
                    switch consolidationResult {
                    case .userCancelled:
                        return .failed(.userCancelled)
                    case .success:
                        break
                    }
                }
            }
            return .passed([])
        }
        
    }
    
    func checkPreconditions(
        transferTo destination: Payment.TransferDestination,
        tokens: [String: MixinTokenItem], // Key is asset id
        on parent: UIViewController,
        onFailure: @MainActor @escaping (PaymentPreconditionFailureReason) -> Void,
        onSuccess: @MainActor @escaping (any InvoicePaymentOperation, [PaymentPreconditionIssue]) -> Void
    ) {
        Task {
            var preconditions: [PaymentPrecondition] = [
                NoPendingTransactionPrecondition(),
                OutputsReadyPrecondition(entries: entries, tokens: tokens),
            ] + entries.flatMap { entry in
                entry.references.compactMap { reference in
                    switch reference {
                    case .hash(let hash):
                        ReferenceValidityPrecondition(reference: hash)
                    case .index:
                        nil // Validated in Invoice.init
                    }
                }
            }
            let paidEntriesHash: [String]
            if sendingSameTokenMultipleTimes {
                do {
                    let hashes = try await SafeAPI.transactions(ids: entries.map(\.traceID))
                        .reduce(into: [:]) { result, transaction in
                            result[transaction.requestID] = transaction.transactionHash
                        }
                    if hashes.isEmpty {
                        paidEntriesHash = []
                    } else if let firstHash = hashes[entries[0].traceID] {
                        var results = [firstHash]
                        var successiveEntriesMustBeUnpaid = false
                        for entry in entries.dropFirst() {
                            let hash = hashes[entry.traceID]
                            if successiveEntriesMustBeUnpaid {
                                if hash != nil {
                                    throw CheckingError.entryPaidAfterUnpaid
                                }
                            } else {
                                if let hash {
                                    results.append(hash)
                                } else {
                                    successiveEntriesMustBeUnpaid = true
                                }
                            }
                        }
                        paidEntriesHash = results
                    } else {
                        throw CheckingError.entryPaidIntermediately
                    }
                    if paidEntriesHash.count == entries.count {
                        throw CheckingError.alreadyPaid
                    }
                } catch {
                    await MainActor.run {
                        onFailure(.description(error.localizedDescription))
                    }
                    return
                }
            } else {
                paidEntriesHash = []
                let alreadyPaid = AlreadyPaidPrecondition(traceIDs: entries.map(\.traceID))
                preconditions.append(alreadyPaid)
            }
            switch await check(preconditions: preconditions) {
            case .failed(let reason):
                await MainActor.run {
                    onFailure(reason)
                }
            case .passed(let issues):
                let memo: TransferExtra? = {
                    guard let entry = entries.first else {
                        return nil
                    }
                    return if entry.isStorage {
                        .hexEncoded(entry.extra.hexEncodedString())
                    } else if let extra = String(data: entry.extra, encoding: .utf8) {
                        .plain(extra)
                    } else {
                        nil
                    }
                }()
                if sendingSameTokenMultipleTimes {
                    var transactions: [NonAtomicInvoicePaymentOperation.Transaction] = []
                    for entry in entries {
                        guard let token = tokens[entry.assetID] else {
                            await MainActor.run {
                                // Not expected to happen, this issue could be found by `OutputsReadyPrecondition`
                                onFailure(.description(R.string.localizable.insufficient_balance()))
                            }
                            return
                        }
                        transactions.append(.init(entry: entry, token: token))
                    }
                    let operation = NonAtomicInvoicePaymentOperation(
                        destination: destination,
                        transactions: transactions,
                        paidEntriesHash: paidEntriesHash,
                        memo: memo,
                    )
                    await MainActor.run {
                        onSuccess(operation, issues)
                    }
                } else {
                    var transactions: [AtomicInvoicePaymentOperation.Transaction] = []
                    for entry in entries {
                        guard let token = tokens[entry.assetID] else {
                            await MainActor.run {
                                // Not expected to happen, this issue could be found by caller
                                onFailure(.description(R.string.localizable.insufficient_balance()))
                            }
                            return
                        }
                        let outputCollectionResult = await collectOutputs(token: token, amount: entry.decimalAmount, on: parent)
                        switch outputCollectionResult {
                        case .success(let collection):
                            let transaction = AtomicInvoicePaymentOperation.Transaction(
                                entry: entry,
                                token: token,
                                outputCollection: collection
                            )
                            transactions.append(transaction)
                        case .failure(let reason):
                            await MainActor.run {
                                onFailure(reason)
                            }
                            return
                        }
                    }
                    let operation = AtomicInvoicePaymentOperation(
                        destination: destination,
                        transactions: transactions,
                        memo: memo,
                    )
                    await MainActor.run {
                        onSuccess(operation, issues)
                    }
                }
            }
        }
    }
    
}
