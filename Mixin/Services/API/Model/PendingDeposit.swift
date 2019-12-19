import Foundation

struct PendingDeposit: Codable {
    
    let transactionId: String
    let transactionHash: String
    let sender: String
    let amount: String
    let confirmations: Int
    let threshold: Int
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case transactionHash = "transaction_hash"
        case sender
        case amount
        case confirmations
        case threshold
        case createdAt = "created_at"
    }
    
    func makeSnapshot(assetId: String) -> Snapshot {
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
