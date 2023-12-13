import Foundation
import GRDB
import Tip

public struct Output {
    
    public enum State: String {
        case unspent
        case signed
        case spent
    }
    
    public let id: String
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
    public let createdAt: String
    public let updatedAt: String
    public let signedBy: String
    public let signedAt: String
    public let spentAt: String
    public let sequence: Int
    
    public init(
        id: String, transactionHash: String, outputIndex: Int, asset: String,
        amount: String, mask: String, keys: [String], receivers: [String],
        receiversHash: String, receiversThreshold: Int, extra: String, state: String,
        createdAt: String, updatedAt: String, signedBy: String, signedAt: String,
        spentAt: String, sequence: Int
    ) {
        self.id = id
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
    
    public init(change: KernelUtxo, asset: String, mask: String, keys: [String], lastOutput: Output) {
        self.init(id: "\(change.hash):\(change.index)".uuidDigest(),
                  transactionHash: change.hash,
                  outputIndex: change.index,
                  asset: asset,
                  amount: change.amount,
                  mask: mask,
                  keys: keys,
                  receivers: lastOutput.receivers,
                  receiversHash: lastOutput.receiversHash,
                  receiversThreshold: 1,
                  extra: "",
                  state: Output.State.unspent.rawValue,
                  createdAt: Date().toUTCString(),
                  updatedAt: "",
                  signedBy: "",
                  signedAt: "",
                  spentAt: "",
                  sequence: 0)
    }
    
    public static func consolidation(
        hash: String, asset: String, amount: String, mask: String, keys: [String],
        createdAt: String, lastOutput: Output
    ) -> Output {
        Output(id: "\(hash):0".uuidDigest(),
               transactionHash: hash,
               outputIndex: 0,
               asset: asset,
               amount: amount,
               mask: mask,
               keys: keys,
               receivers: lastOutput.receivers,
               receiversHash: lastOutput.receiversHash,
               receiversThreshold: 1,
               extra: "",
               state: Output.State.unspent.rawValue,
               createdAt: createdAt,
               updatedAt: "",
               signedBy: "",
               signedAt: "",
               spentAt: "",
               sequence: 0)
    }
    
}

extension Output: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case id = "output_id"
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
