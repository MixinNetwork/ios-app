import Foundation

public struct RequestTransactionResponse {
    
    public let requestID: String
    public let views: [String]
    
}

extension RequestTransactionResponse: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case views
    }
    
}
