import Foundation

public struct PINLogResponse: Codable {
    
    public let logId: String
    public let code: String
    public let ipAddress: String
    public let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case logId = "log_id"
        case code = "code"
        case ipAddress = "ip_address"
        case createdAt = "created_at"
    }
    
}
