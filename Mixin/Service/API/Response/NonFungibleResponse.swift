import Foundation

struct NonFungibleResponse: Codable {
    
    //TODO: ‼️ remove 
    let action: String
    
    let type: String
    let userId: String
    let outputId: String
    let tokenId: String
    let transactionHash: String
    let outputIndex: Int64
    let amount: String
    let sendersThreshold: Int64
    let senders: [String]
    let receiversThreshold: Int64
    let receivers: [String]
    let memo: String?
    let state: String
    let createdAt: String
    let updatedAt: String
    let signedBy: String
    let signedTx: String
    
    enum CodingKeys: String, CodingKey {
        case action
        
        case type
        case userId = "user_id"
        case outputId = "output_id"
        case tokenId = "token_id"
        case transactionHash = "transaction_hash"
        case outputIndex = "output_index"
        case amount
        case sendersThreshold = "senders_threshold"
        case senders
        case receiversThreshold = "receivers_threshold"
        case receivers
        case memo
        case state
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case signedBy = "signed_by"
        case signedTx = "signed_tx"
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
