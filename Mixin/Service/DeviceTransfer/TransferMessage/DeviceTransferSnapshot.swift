import Foundation
import MixinServices

struct DeviceTransferSnapshot {
    
    let snapshotId: String
    let type: String
    let assetId: String
    let amount: String
    let opponentId: String?
    let transactionHash: String?
    let sender: String?
    let receiver: String?
    let memo: String?
    let confirmations: Int?
    let traceId: String?
    let createdAt: String

    init(snapshot: Snapshot) {
        self.snapshotId = snapshot.snapshotId
            self.type = snapshot.type
            self.assetId = snapshot.assetId
            self.amount = snapshot.amount
            self.opponentId = snapshot.opponentId
            self.transactionHash = snapshot.transactionHash
            self.sender = snapshot.sender
            self.receiver = snapshot.receiver
            self.memo = snapshot.memo
            self.confirmations = snapshot.confirmations
            self.traceId = snapshot.traceId
            self.createdAt = snapshot.createdAt
    }
    
    func toSnapshot() -> Snapshot {
        Snapshot(snapshotId: snapshotId,
                 type: type,
                 assetId: assetId,
                 amount: amount,
                 transactionHash: transactionHash,
                 sender: sender,
                 opponentId: opponentId,
                 memo: memo,
                 receiver: receiver,
                 confirmations: confirmations,
                 traceId: traceId,
                 createdAt: createdAt,
                 snapshotHash: nil,
                 openingBalance: "",
                 closingBalance: "")
    }
    
}

extension DeviceTransferSnapshot: Codable {
    
    enum CodingKeys: String, CodingKey {
        case snapshotId = "snapshot_id"
        case type
        case assetId = "asset_id"
        case amount
        case opponentId = "opponent_id"
        case transactionHash = "transaction_hash"
        case sender
        case receiver
        case memo
        case confirmations
        case traceId = "trace_id"
        case createdAt = "created_at"
    }

}
