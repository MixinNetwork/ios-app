import Foundation

struct WithdrawalRequest: Codable {

    let addressId: String
    let amount: String
    let traceId: String
    var pin: String
    let memo: String

    enum CodingKeys: String, CodingKey {
        case addressId = "address_id"
        case amount
        case traceId = "trace_id"
        case memo
        case pin
    }
}
