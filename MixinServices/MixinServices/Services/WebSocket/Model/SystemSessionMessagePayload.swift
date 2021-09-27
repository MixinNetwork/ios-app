import Foundation

struct SystemSessionMessagePayload: Codable {

    let action: String
    let userId: String
    let sessionId: String
    let publicKey: String?
    
    enum CodingKeys: String, CodingKey {
        case action
        case userId = "user_id"
        case sessionId = "session_id"
        case publicKey = "public_key"
    }
    
}

enum SystemSessionMessageAction: String {
    case PROVISION
    case DESTROY
}
