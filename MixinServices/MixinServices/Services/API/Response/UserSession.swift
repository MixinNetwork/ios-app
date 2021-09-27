import Foundation

public struct UserSession: Codable {
    
    public let userId: String
    public let sessionId: String
    public let platform: String?
    public let publicKey: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case sessionId = "session_id"
        case platform
        case publicKey = "public_key"
    }
    
}

extension UserSession {
    
    public var uniqueIdentifier: String {
        return "\(userId)\(sessionId)"
    }
    
}
