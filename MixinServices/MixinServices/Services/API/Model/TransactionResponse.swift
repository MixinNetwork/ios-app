import Foundation

public struct TransactionResponse {
    
    public let requestID: String
    public let userID: String
    public let amount: String
    public let createdAt: String
    public let snapshotID: String
    
}

extension TransactionResponse: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case userID = "user_id"
        case amount
        case createdAt = "created_at"
        case snapshotID = "snapshot_id"
    }
    
}
