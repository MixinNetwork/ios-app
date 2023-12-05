import Foundation

public struct PostTransactionResponse {
    
    public let requestID: String
    public let userID: String
    public let amount: String
    public let transactionHash: String
    public let createdAt: String
    
    public var snapshotID: String {
        "\(userID):\(transactionHash)".uuidDigest()
    }
    
}

extension PostTransactionResponse: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case userID = "user_id"
        case amount
        case transactionHash = "transaction_hash"
        case createdAt = "created_at"
    }
    
}
