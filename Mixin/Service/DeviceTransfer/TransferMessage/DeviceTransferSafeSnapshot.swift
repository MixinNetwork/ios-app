import Foundation
import MixinServices

struct DeviceTransferSafeSnapshot {
    
    let id: String
    let type: String
    let assetID: String
    let amount: String
    let userID: String
    let opponentID: String
    let memo: String
    let transactionHash: String
    let createdAt: String
    let traceID: String?
    let confirmations: Int?
    let openingBalance: String?
    let closingBalance: String?
    let inscriptionHash: String?
    let deposit: SafeSnapshot.Deposit?
    let withdrawal: SafeSnapshot.Withdrawal?
    
    init(safeSnapshot: SafeSnapshot) {
        id = safeSnapshot.id
        type = safeSnapshot.type
        assetID = safeSnapshot.assetID
        amount = safeSnapshot.amount
        userID = safeSnapshot.userID
        opponentID = safeSnapshot.opponentID
        memo = safeSnapshot.memo
        transactionHash = safeSnapshot.transactionHash
        createdAt = safeSnapshot.createdAt
        traceID = safeSnapshot.traceID
        confirmations = safeSnapshot.confirmations
        openingBalance = safeSnapshot.openingBalance
        closingBalance = safeSnapshot.closingBalance
        inscriptionHash = safeSnapshot.inscriptionHash
        deposit = safeSnapshot.deposit
        withdrawal = safeSnapshot.withdrawal
    }
    
    func toSafeSnapshot() -> SafeSnapshot {
        SafeSnapshot(id: id,
                     type: type,
                     assetID: assetID,
                     amount: amount,
                     userID: userID,
                     opponentID: opponentID,
                     memo: memo,
                     transactionHash: transactionHash,
                     createdAt: createdAt,
                     traceID: traceID,
                     confirmations: confirmations,
                     openingBalance: openingBalance,
                     closingBalance: closingBalance, 
                     inscriptionHash: inscriptionHash,
                     deposit: deposit,
                     withdrawal: withdrawal)
    }
    
}

extension DeviceTransferSafeSnapshot: DeviceTransferRecord {
    
    enum CodingKeys: String, CodingKey {
        case id = "snapshot_id"
        case type
        case assetID = "asset_id"
        case amount
        case userID = "user_id"
        case opponentID = "opponent_id"
        case memo
        case transactionHash = "transaction_hash"
        case createdAt = "created_at"
        case traceID = "trace_id"
        case confirmations
        case openingBalance = "opening_balance"
        case closingBalance = "closing_balance"
        case inscriptionHash = "inscription_hash"
        case deposit
        case withdrawal
    }
    
}
