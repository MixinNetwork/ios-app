import Foundation

public struct SafePendingDeposit {
    
    public let id: String
    public let transactionHash: String
    public let amount: String
    public let confirmations: Int
    public let createdAt: String
    
}

extension SafePendingDeposit: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case id = "deposit_id"
        case transactionHash = "transaction_hash"
        case amount
        case confirmations
        case createdAt = "created_at"
    }
    
}
