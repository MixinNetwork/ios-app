import Foundation

public struct RequestTransactionResponse {
    
    public let requestID: String
    public let state: String
    public let views: [String]
    
}

extension RequestTransactionResponse: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case state
        case views
    }
    
}
