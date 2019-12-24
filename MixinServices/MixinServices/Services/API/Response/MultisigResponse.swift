public struct MultisigResponse: Codable {
    
    public let codeId: String
    public let requestId: String
    public let action: String
    public let userId: String
    public let assetId: String
    public let amount: String
    public let senders: [String]
    public let receivers: [String]
    public let state: String
    public let transactionHash: String
    public let rawTransaction: String
    public let createdAt: String
    public let memo: String?
    
    enum CodingKeys: String, CodingKey {
        case codeId = "code_id"
        case requestId = "request_id"
        case action
        case userId = "user_id"
        case assetId = "asset_id"
        case amount
        case senders
        case receivers
        case state
        case transactionHash = "transaction_hash"
        case rawTransaction = "raw_transaction"
        case createdAt = "created_at"
        case memo
    }
    
}

public enum MultisigState: String {
    case initial
    case unlocked
    case signed
}

public enum MultisigAction: String {
    case sign
    case unlock
}
