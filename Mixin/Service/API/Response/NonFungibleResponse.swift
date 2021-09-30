import Foundation

struct NonFungibleResponse: Codable {
    
    let type: String
    let codeId: String
    let requestId: String
    let userId: String
    let tokenId: String
    let amount: String
    let sendersThreshold: Int64
    let senders: [String]
    let receiversThreshold: Int64
    let receivers: [String]
    let signers: [String]
    let action: String
    let state: String
    let transactionHash: String
    let rawTransaction: String
    let createdAt: String
    let memo: String?
    
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

enum NonFungibleState: String {
    case initial
    case unlocked
    case signed
}

enum NonFungibleAction: String {
    case unlock
    case sign
}
