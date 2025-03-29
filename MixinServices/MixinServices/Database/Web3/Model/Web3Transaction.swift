import Foundation
import GRDB

public class Web3Transaction: Codable {
    
    enum CodingKeys: String, CodingKey {
        case transactionID = "transaction_id"
        case transactionHash = "transaction_hash"
        case outputIndex = "output_index"
        case blockNumber = "block_number"
        case sender = "sender"
        case receiver = "receiver"
        case outputHash = "output_hash"
        case chainID = "chain_id"
        case assetID = "asset_id"
        case amount = "amount"
        case transactionType = "transaction_type"
        case status = "status"
        case transactionAt = "transaction_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public enum TransactionType: String {
        case receive
        case send
        case other
        case contract
    }
    
    public enum TransactionStatus: String {
        case pending
        case success
        case failed
    }
    
    public let transactionID: String
    public let transactionHash: String
    public let outputIndex: Int
    public let blockNumber: Int
    public let sender: String
    public let receiver: String
    public let outputHash: String
    public let chainID: String
    public let assetID: String
    public let amount: String
    public let transactionType: UnknownableEnum<TransactionType>
    public let status: UnknownableEnum<TransactionStatus>
    public let transactionAt: String
    public let createdAt: String
    public let updatedAt: String
    
    public private(set) lazy var compactSender = Address.compactRepresentation(of: sender)
    public private(set) lazy var compactReceiver = Address.compactRepresentation(of: receiver)
    public private(set) lazy var decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) ?? 0
    
    public var signedDecimalAmount: Decimal {
        switch transactionType.knownCase {
        case .send:
            -decimalAmount
        case .receive, .contract, .other, .none:
            decimalAmount
        }
    }
    
    public init(
        transactionID: String, transactionHash: String, outputIndex: Int,
        blockNumber: Int, sender: String, receiver: String, outputHash: String,
        chainID: String, assetID: String, amount: String,
        transactionType: UnknownableEnum<Web3Transaction.TransactionType>,
        status: UnknownableEnum<Web3Transaction.TransactionStatus>,
        transactionAt: String, createdAt: String, updatedAt: String
    ) {
        self.transactionID = transactionID
        self.transactionHash = transactionHash
        self.outputIndex = outputIndex
        self.blockNumber = blockNumber
        self.sender = sender
        self.receiver = receiver
        self.outputHash = outputHash
        self.chainID = chainID
        self.assetID = assetID
        self.amount = amount
        self.transactionType = transactionType
        self.status = status
        self.transactionAt = transactionAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
}

extension Web3Transaction: TableRecord, PersistableRecord, MixinFetchableRecord, MixinEncodableRecord {
    
    public static let databaseTableName = "transactions"
    
}

extension Web3Transaction {
    
    public struct Filter: CustomStringConvertible {
        
        // For array-type properties, when the value is empty,
        // it indicates that this filter should not be applied.
        
        public var type: TransactionType?
        public var tokens: [Web3TokenItem]
        public var addresses: [AddressItem]
        public var startDate: Date?
        public var endDate: Date?
        
        public var description: String {
            "<Filter type: \(type), tokens: \(tokens.map(\.symbol)), addresses: \(addresses.map(\.label)), startDate: \(startDate), endDate: \(endDate)>"
        }
        
        public init(
            type: TransactionType? = nil,
            tokens: [Web3TokenItem] = [],
            addresses: [AddressItem] = [],
            startDate: Date? = nil,
            endDate: Date? = nil
        ) {
            self.type = type
            self.tokens = tokens
            self.addresses = addresses
            self.startDate = startDate
            self.endDate = endDate
        }
        
        public func isIncluded(transaction: Web3Transaction) -> Bool {
            var isIncluded = true
            if let type {
                isIncluded = isIncluded && transaction.transactionType.knownCase == type
            }
            if !tokens.isEmpty {
                isIncluded = isIncluded && tokens.contains(where: { $0.assetID == transaction.assetID })
            }
            if !addresses.isEmpty {
                isIncluded = isIncluded && addresses.contains(where: { address in
                    transaction.sender == address.destination || transaction.receiver == address.destination
                })
            }
            if let startDate {
                isIncluded = isIncluded && transaction.createdAt.toUTCDate() >= startDate
            }
            if let endDate {
                isIncluded = isIncluded && transaction.createdAt.toUTCDate() <= endDate
            }
            return isIncluded
        }
        
    }
    
}
