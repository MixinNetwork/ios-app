import Foundation

public struct TransactionRequest {
    
    public let id: String
    public let raw: String
    public let feeType: FeeType?
    
    public init(id: String, raw: String, feeType: FeeType? = nil) {
        self.id = id
        self.raw = raw
        self.feeType = feeType
    }
    
}

extension TransactionRequest: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case id = "request_id"
        case raw
        case feeType = "fee_type"
    }
    
}
