import Foundation

struct PaymentCodeResponse: Codable {

    let codeId: String
    let assetId: String
    let amount: String
    let receivers: [String]
    let status: String
    let threshold: Int
    let memo: String
    let traceId: String
    let createdAt: String

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
