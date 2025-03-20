import Foundation
import CryptoKit
import MixinServices

struct Invoice: PaymentPreconditionChecker {
    
    enum Reference {
        case hash(String)
        case index(Int)
    }
    
    struct Entry {
        let traceID: String
        let assetID: String
        let amount: String
        let decimalAmount: Decimal
        let memo: String
        let memoData: Data
        let references: [Reference]
    }
    
    let recipient: MIXAddress
    let entries: [Entry]
    
}

extension Invoice {
    
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
        case duplicatedAssetID
        case emptyEntries
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
                let memo = String(data: extra, encoding: .utf8),
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
            
            let entry = Entry(
                traceID: traceID,
                assetID: assetID,
                amount: amount,
                decimalAmount: decimalAmount,
                memo: memo,
                memoData: extra,
                references: references
            )
            entries.append(entry)
        }
        
        if entries.isEmpty {
            throw InitError.emptyEntries
        }
        let assetIDs = Set(entries.map(\.assetID))
        if assetIDs.count != entries.count {
            throw InitError.duplicatedAssetID
        }
        
        self.recipient = recipient
        self.entries = entries
    }
    
}

extension Invoice {
    
    func checkPreconditions(
        transferTo destination: Payment.TransferDestination,
        tokens: [String: MixinTokenItem],
        on parent: UIViewController,
        onFailure: @MainActor @escaping (PaymentPreconditionFailureReason) -> Void,
        onSuccess: @MainActor @escaping (InvoicePaymentOperation, [PaymentPreconditionIssue]) -> Void
    ) {
        Task {
            let preconditions: [PaymentPrecondition] = [
                NoPendingTransactionPrecondition(),
                AlreadyPaidPrecondition(traceIDs: entries.map(\.traceID))
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
            switch await check(preconditions: preconditions) {
            case .failed(let reason):
                await MainActor.run {
                    onFailure(reason)
                }
            case .passed(let issues):
                var transactions: [InvoicePaymentOperation.Transaction] = []
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
                        let transaction = InvoicePaymentOperation.Transaction(
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
                let operation = InvoicePaymentOperation(destination: destination, transactions: transactions)
                await MainActor.run {
                    onSuccess(operation, issues)
                }
            }
        }
    }
    
}
