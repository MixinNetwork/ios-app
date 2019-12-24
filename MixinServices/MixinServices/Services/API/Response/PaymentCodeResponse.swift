import Foundation

public struct PaymentCodeResponse: Codable {
    
    public let codeId: String
    public let assetId: String
    public let amount: String
    public let receivers: [String]
    public let status: String
    public let threshold: Int
    public let memo: String
    public let traceId: String
    public let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case codeId = "code_id"
        case assetId = "asset_id"
        case amount
        case receivers
        case status
        case threshold
        case memo
        case traceId = "trace_id"
        case createdAt = "created_at"
    }
    
}
