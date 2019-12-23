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
    
    public let assetId: String
    public let opponentMultisig: OpponentMultisig
    public let amount: String
    public var pin: String
    public let traceId: String
    public let memo: String
    
    public init(assetId: String, opponentMultisig: OpponentMultisig, amount: String, pin: String, traceId: String, memo: String) {
        self.assetId = assetId
        self.opponentMultisig = opponentMultisig
        self.amount = amount
        self.pin = pin
        self.traceId = traceId
        self.memo = memo
    }
    
}

public struct OpponentMultisig: Encodable {
    
    public let receivers: [String]
    public let threshold: Int
    
    public init(receivers: [String], threshold: Int) {
        self.receivers = receivers
        self.threshold = threshold
    }
    
}
