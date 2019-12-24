import Foundation

public struct PendingDeposit: Codable {
    
    public let transactionId: String
    public let transactionHash: String
    public let sender: String
    public let amount: String
    public let confirmations: Int
    public let threshold: Int
    public let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case transactionHash = "transaction_hash"
        case sender
        case amount
        case confirmations
        case threshold
        case createdAt = "created_at"
    }
    
    public func makeSnapshot(assetId: String) -> Snapshot {
        return Snapshot(snapshotId: transactionId,
                        type: SnapshotType.pendingDeposit.rawValue,
                        assetId: assetId,
                        amount: amount,
                        transactionHash: transactionHash,
                        sender: sender,
                        opponentId: myUserId,
                        memo: nil,
                        receiver: nil,
                        confirmations: confirmations,
                        traceId: "",
                        createdAt: createdAt)
    }
    
}
