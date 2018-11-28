import WCDBSwift

struct SnapshotItem {

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
    let createdAt: String
    
    let assetSymbol: String?
    
    let opponentUserId: String?
    let opponentUserFullName: String?
    let opponentUserAvatarUrl: String?
    let opponentUserIdentityNumber: String?
    
}
