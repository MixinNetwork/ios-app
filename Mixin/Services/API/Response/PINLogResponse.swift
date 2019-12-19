import Foundation

struct PINLogResponse: Codable {

    let logId: String
    let code: String
    let ipAddress: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case logId = "log_id"
        case code = "code"
        case ipAddress = "ip_address"
        case createdAt = "created_at"
    }

}
