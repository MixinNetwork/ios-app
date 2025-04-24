import Foundation
import GRDB

public class Web3Transaction: Codable, Identifiable {
    
    public enum CodingKeys: String, CodingKey {
        case transactionHash = "transaction_hash"
        case chainID = "chain_id"
        case address = "address"
        case transactionType = "transaction_type"
        case status = "status"
        case blockNumber = "block_number"
        case fee = "fee"
        case senders = "senders"
        case receivers = "receivers"
        case approvals = "approvals"
        case sendAssetID = "send_asset_id"
        case receiveAssetID = "receive_asset_id"
        case transactionAt = "transaction_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public let transactionHash: String
    public let chainID: String
    public let address: String
    public let transactionType: UnknownableEnum<TransactionType>
    public let status: Status
    public let blockNumber: Int
    public let fee: String
    public let senders: [Sender]?
    public let receivers: [Receiver]?
    public let approvals: [Approval]?
    public let sendAssetID: String?
    public let receiveAssetID: String?
    public let transactionAt: String
    public let createdAt: String
    public let updatedAt: String
    
    public lazy var compactHash = TextTruncation.truncateMiddle(
        string: transactionHash,
        prefixCount: 8,
        suffixCount: 6
    )
    
    public lazy var transferAssetID: String? = {
        switch transactionType.knownCase {
        case .transferIn:
            receiveAssetID
        case .transferOut:
            sendAssetID
        default:
            nil
        }
    }()
    
    public lazy var directionalTransferAmount: Decimal? = {
        switch transactionType.knownCase {
        case .transferIn:
            if let amount = receivers?.first?.amount {
                Decimal(string: amount, locale: .enUSPOSIX)
            } else {
                nil
            }
        case .transferOut:
            if let amount = senders?.first?.amount,
               let decimalAmount = Decimal(string: amount, locale: .enUSPOSIX)
            {
                -decimalAmount
            } else {
                nil
            }
        default:
            nil
        }
    }()
    
    public lazy var localizedTransferAmount: String? = {
        guard let amount = directionalTransferAmount else {
            return nil
        }
        return CurrencyFormatter.localizedString(
            from: amount,
            format: .precision,
            sign: .always
        )
    }()
    
    public var allAssetIDs: Set<String> {
        let senderIDs = senders?.map(\.assetID) ?? []
        let receiverIDs = receivers?.map(\.assetID) ?? []
        let approvalIDs = approvals?.map(\.assetID) ?? []
        return Set(senderIDs + receiverIDs + approvalIDs)
    }
    
    public init(
        transactionHash: String, chainID: String, address: String,
        transactionType: UnknownableEnum<TransactionType>,
        status: Status, blockNumber: Int, fee: String,
        senders: [Sender]?, receivers: [Receiver]?, approvals: [Approval]?,
        sendAssetID: String?, receiveAssetID: String?,
        transactionAt: String, createdAt: String, updatedAt: String
    ) {
        self.transactionHash = transactionHash
        self.chainID = chainID
        self.address = address
        self.transactionType = transactionType
        self.status = status
        self.blockNumber = blockNumber
        self.fee = fee
        self.senders = senders
        self.receivers = receivers
        self.approvals = approvals
        self.sendAssetID = sendAssetID
        self.receiveAssetID = receiveAssetID
        self.transactionAt = transactionAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    public func matches(with another: Web3Transaction) -> Bool {
        self.transactionHash == another.transactionHash
        && self.chainID == another.chainID
        && self.address == another.address
    }
    
}

extension Web3Transaction: TableRecord, PersistableRecord, MixinFetchableRecord, MixinEncodableRecord {
    
    public static let databaseTableName = "transactions"
    
}

extension Web3Transaction {
    
    public enum Status: String, Codable {
        case pending
        case success
        case failed
        case notFound = "notfound"
    }
    
    public enum TransactionType: String, Codable {
        case transferIn = "transfer_in"
        case transferOut = "transfer_out"
        case swap
        case approval
        case unknown
    }
    
    public class Receiver: Codable {
        
        enum CodingKeys: String, CodingKey {
            case assetID = "asset_id"
            case amount = "amount"
            case to = "to"
        }
        
        public let assetID: String
        public let amount: String
        public let to: String?
        
        public lazy var decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) ?? 0
        public lazy var localizedAmount = CurrencyFormatter.localizedString(
            from: decimalAmount,
            format: .precision,
            sign: .always
        )
        
        public init(assetID: String, amount: String, to: String?) {
            self.assetID = assetID
            self.amount = amount
            self.to = to
        }
        
    }
    
    public class Sender: Codable {
        
        enum CodingKeys: String, CodingKey {
            case assetID = "asset_id"
            case amount = "amount"
            case from = "from"
        }
        
        public let assetID: String
        public let amount: String
        public let from: String?
        
        public lazy var decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) ?? 0
        public lazy var localizedAmount = CurrencyFormatter.localizedString(
            from: -decimalAmount,
            format: .precision,
            sign: .always
        )
        
        public init(assetID: String, amount: String, from: String?) {
            self.assetID = assetID
            self.amount = amount
            self.from = from
        }
        
    }
    
    public class Approval: Codable {
        
        public enum ApprovalType: String {
            case unlimited
            case other = "approval"
        }
        
        public enum CodingKeys: String, CodingKey {
            case assetID = "asset_id"
            case amount = "amount"
            case to = "to"
            case approvalType = "approval_type"
        }
        
        public let assetID: String
        public let amount: String
        public let to: String
        public let approvalType: UnknownableEnum<ApprovalType>
        
        public lazy var decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) ?? 0
        public lazy var localizedAmount = CurrencyFormatter.localizedString(
            from: decimalAmount,
            format: .precision,
            sign: .never
        )
        
        public init(assetID: String, amount: String, to: String, approvalType: ApprovalType) {
            self.assetID = assetID
            self.amount = amount
            self.to = to
            self.approvalType = .known(approvalType)
        }
        
    }
    
    public enum ApprovalAmount {
        case unlimited
        case limited(String)
    }
    
}

extension Web3Transaction {
    
    public enum DisplayType {
        case receive
        case send
        case swap
        case approval
        case pending
    }
    
    public enum Order {
        case newest
        case oldest
    }
    
    public struct Filter: CustomStringConvertible {
        
        // For array-type properties, when the value is empty,
        // it indicates that this filter should not be applied.
        
        public var type: DisplayType?
        public var tokens: [Web3TokenItem]
        public var addresses: [AddressItem]
        public var startDate: Date?
        public var endDate: Date?
        
        public var description: String {
            "<Filter type: \(type), tokens: \(tokens.map(\.symbol)), addresses: \(addresses.map(\.label)), startDate: \(startDate), endDate: \(endDate)>"
        }
        
        public init(
            type: DisplayType? = nil,
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
        
    }
    
}
