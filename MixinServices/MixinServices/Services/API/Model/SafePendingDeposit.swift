import Foundation

public struct SafePendingDeposit {
    
    public let id: String
    public let assetID: String
    public let transactionHash: String
    public let amount: String
    public let confirmations: Int
    public let createdAt: String
    public let destination: String
    public let tag: String?
    
}

extension SafePendingDeposit: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case id = "deposit_id"
        case assetID = "asset_id"
        case transactionHash = "transaction_hash"
        case amount
        case confirmations
        case createdAt = "created_at"
        case destination
        case tag
    }
    
}

extension SafeSnapshot {
    
    public convenience init(pendingDeposit pd: SafePendingDeposit) {
        self.init(id: pd.id,
                  type: .pending,
                  assetID: pd.assetID,
                  amount: pd.amount,
                  userID: myUserId,
                  opponentID: "",
                  memo: "",
                  transactionHash: "",
                  createdAt: pd.createdAt,
                  traceID: "",
                  confirmations: pd.confirmations,
                  openingBalance: nil,
                  closingBalance: nil, 
                  inscriptionHash: "",
                  deposit: .init(hash: pd.transactionHash, sender: ""),
                  withdrawal: nil)
    }
    
}
