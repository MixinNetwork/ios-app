import Foundation

public struct SafeMultisigResponse: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case assetID = "asset_id"
        case amount
        case sendersThreshold = "senders_threshold"
        case senders
        case signers
        case rawTransaction = "raw_transaction"
        case receivers
        case views
    }
    
    public let requestID: String
    public let assetID: String
    public let amount: String
    public let sendersThreshold: Int
    public let senders: [String]
    public let signers: [String]
    public let rawTransaction: String
    public let receivers: [Receiver]
    public let views: [String]
    
}

extension SafeMultisigResponse {
    
    public struct Receiver: Decodable {
        
        enum CodingKeys: String, CodingKey {
            case members
            case threshold
        }
        
        public let members: [String]
        public let threshold: Int
        
    }
    
}
