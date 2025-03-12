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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case transactionAt = "transaction_at"
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
    public let transactionType: String
    public let status: String
    public let createdAt: String
    public let updatedAt: String
    public let transactionAt: String
    
    public private(set) lazy var decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) ?? 0
    
}

extension Web3Transaction: TableRecord, PersistableRecord, MixinFetchableRecord, MixinEncodableRecord {
    
    public static let databaseTableName = "transactions"
    
}

extension Web3Transaction {
    
    public struct Filter: CustomStringConvertible {
        
        // For array-type properties, when the value is empty,
        // it indicates that this filter should not be applied.
        
        public var type: SafeSnapshot.DisplayType?
        public var tokens: [Web3TokenItem]
        public var addresses: [AddressItem]
        public var startDate: Date?
        public var endDate: Date?
        
        public var description: String {
            "<Filter type: \(type), tokens: \(tokens.map(\.symbol)), addresses: \(addresses.map(\.label)), startDate: \(startDate), endDate: \(endDate)>"
        }
        
        public init(
            type: SafeSnapshot.DisplayType? = nil,
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
        
        public func isIncluded(snapshot: SafeSnapshot) -> Bool {
            var isIncluded = true
            if let type {
                isIncluded = isIncluded && snapshot.displayTypes.contains(type)
            }
            if !tokens.isEmpty {
                isIncluded = isIncluded && tokens.contains(where: { $0.assetID == snapshot.assetID })
            }
            if !addresses.isEmpty {
                isIncluded = isIncluded && addresses.contains(where: { address in
                    snapshot.deposit?.sender == address.destination || snapshot.withdrawal?.receiver == address.destination
                })
            }
            if let startDate {
                isIncluded = isIncluded && snapshot.createdAt.toUTCDate() >= startDate
            }
            if let endDate {
                isIncluded = isIncluded && snapshot.createdAt.toUTCDate() <= endDate
            }
            return isIncluded
        }
        
    }
    
}
