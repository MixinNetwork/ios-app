import Foundation

public struct RawTransactionRequest: Encodable {

    enum CodingKeys: String, CodingKey {
        case assetId = "asset_id"
        case opponentMultisig = "opponent_multisig"
        case amount
        case pin
        case traceId = "trace_id"
        case memo
    }

    let assetId: String
    let opponentMultisig: OpponentMultisig
    let amount: String
    var pin: String
    let traceId: String
    let memo: String
    
}

struct OpponentMultisig: Encodable {
    let receivers: [String]
    let threshold: Int
}
