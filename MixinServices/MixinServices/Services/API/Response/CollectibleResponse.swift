import Foundation

public struct CollectibleResponse: Codable {
    
    public let type: String
    public let codeId: String
    public let requestId: String
    public let userId: String
    public let tokenId: String
    public let amount: String
    public let sendersThreshold: Int64
    public let senders: [String]
    public let receiversThreshold: Int64
    public let receivers: [String]
    public let signers: [String]
    public let action: String
    public let state: String
    public let transactionHash: String
    public let rawTransaction: String
    public let createdAt: String
    public let memo: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case codeId = "code_id"
        case requestId = "request_id"
        case userId = "user_id"
        case tokenId = "token_id"
        case amount
        case sendersThreshold = "senders_threshold"
        case senders
        case receiversThreshold = "receivers_threshold"
        case receivers
        case signers
        case action
        case state
        case transactionHash = "transaction_hash"
        case rawTransaction = "raw_transaction"
        case createdAt = "created_at"
        case memo
    }
    
}

public enum CollectibleState: String {
    case initial
    case unlocked
    case signed
}

public enum CollectibleAction: String {
    case unlock
    case sign
}
