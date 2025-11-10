import Foundation

public struct TransactionRequest {
    
    public let id: String
    public let raw: String
    
    public init(id: String, raw: String) {
        self.id = id
        self.raw = raw
    }
    
}

extension TransactionRequest: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case id = "request_id"
        case raw
    }
    
}
