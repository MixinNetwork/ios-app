import Foundation

public struct TransactionResponse {
    
    public let requestID: String
    public let amount: String
    public let transactionHash: String
    public let asset: String
    public let extra: String
    public let state: String
    public let rawTransaction: String
    public let createdAt: String
    public let updatedAt: String
    public let snapshotID: String
    public let snapshotHash: String
    public let snapshotAt: String
    
}

extension TransactionResponse: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case amount
        case transactionHash = "transaction_hash"
        case asset
        case extra
        case state
        case rawTransaction = "raw_transaction"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case snapshotID = "snapshot_id"
        case snapshotHash = "snapshot_hash"
        case snapshotAt = "snapshot_at"
    }
    
}
