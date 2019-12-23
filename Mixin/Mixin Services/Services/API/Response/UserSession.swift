import Foundation

public struct UserSession: Codable {
    
    let userId: String
    let sessionId: String
    let platform: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case sessionId = "session_id"
        case platform
    }
    
}

extension UserSession {
    
    var uniqueIdentifier: String {
        return "\(userId)\(sessionId)"
    }
    
}
