import Foundation

public struct TransactionResponse {
    
    public let type: String
    public let requestID: String
    public let userID: String
    public let amount: String
    public let transactionHash: String
    public let asset: String
    public let sendersHash: String
    public let sendersThreshold: Int
    public let senders: [String]
    public let signers: [String]
    public let extra: String
    public let state: String
    public let rawTransaction: String
    public let createdAt: Date
    public let updatedAt: Date
    public let snapshotHash: String
    public let snapshotAt: Date
    
}

extension TransactionResponse: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case type
        case requestID = "request_id"
        case userID = "user_id"
        case amount
        case transactionHash = "transaction_hash"
        case asset
        case sendersHash = "senders_hash"
        case sendersThreshold = "senders_threshold"
        case senders
        case signers
        case extra
        case state
        case rawTransaction = "raw_transaction"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case snapshotHash = "snapshot_hash"
        case snapshotAt = "snapshot_at"
    }
    
}
