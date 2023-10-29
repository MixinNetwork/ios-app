import Foundation
import GRDB

public struct Output {
    
    public enum State: String {
        case unspent
        case signed
        case pending
        case spent
    }
    
    public let outputID: String
    public let transactionHash: String
    public let outputIndex: Int
    public let asset: String
    public let amount: String
    public let mask: String
    public let keys: [String]
    public let receivers: [String]
    public let receiversHash: String
    public let receiversThreshold: Int
    public let extra: String
    public let state: String
    public let createdAt: Date
    public let updatedAt: Date
    public let signedBy: String
    public let signedAt: Date
    public let spentAt: Date
    public let sequence: Int
    
    public init(
        outputID: String, transactionHash: String, outputIndex: Int, asset: String,
        amount: String, mask: String, keys: [String], receivers: [String],
        receiversHash: String, receiversThreshold: Int, extra: String, state: String,
        createdAt: Date, updatedAt: Date, signedBy: String, signedAt: Date,
        spentAt: Date, sequence: Int
    ) {
        self.outputID = outputID
        self.transactionHash = transactionHash
        self.outputIndex = outputIndex
        self.asset = asset
        self.amount = amount
        self.mask = mask
        self.keys = keys
        self.receivers = receivers
        self.receiversHash = receiversHash
        self.receiversThreshold = receiversThreshold
        self.extra = extra
        self.state = state
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.signedBy = signedBy
        self.signedAt = signedAt
        self.spentAt = spentAt
        self.sequence = sequence
    }
    
}

extension Output: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case outputID = "output_id"
        case transactionHash = "transaction_hash"
        case outputIndex = "output_index"
        case asset
        case amount
        case mask
        case keys
        case receivers
        case receiversHash = "receivers_hash"
        case receiversThreshold = "receivers_threshold"
        case extra
        case state
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case signedBy = "signed_by"
        case signedAt = "signed_at"
        case spentAt = "spent_at"
        case sequence
    }
    
}

extension Output: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "outputs"
    
}
