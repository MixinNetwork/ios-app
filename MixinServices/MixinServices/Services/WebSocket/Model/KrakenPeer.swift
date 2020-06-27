import Foundation

public struct KrakenPeer: Codable {
    
    public let userId: String
    public let sessionId: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case sessionId = "session_id"
    }
    
}

