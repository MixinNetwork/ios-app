import Foundation

public struct TransactionResponse {
    
    public let requestID: String
    public let createdAt: String
    public let snapshotID: String
    
}

extension TransactionResponse: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case createdAt = "created_at"
        case snapshotID = "snapshot_id"
    }
    
}
