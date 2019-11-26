struct MultisigResponse: Codable {

    let codeId: String
    let requestId: String
    let action: String
    let userId: String
    let assetId: String
    let amount: String
    let senders: [String]
    let receivers: [String]
    let state: String
    let transactionHash: String
    let rawTransaction: String
    let createdAt: String
    let memo: String?

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


enum MultisigState: String {
    case initial
    case unlocked
    case signed
}

enum MultisigAction: String {
    case sign
    case unlock
}
