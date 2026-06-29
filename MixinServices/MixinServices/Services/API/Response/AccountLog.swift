import Foundation

public struct AccountLog: Codable {
    
    public enum Category {
        case incorrectPIN
        case all
    }
    
    public let code: String
    public let ipAddress: String
    public let ipLocation: String
    public let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case code = "code"
        case ipAddress = "ip_address"
        case ipLocation = "ip_location"
        case createdAt = "created_at"
    }
    
}
