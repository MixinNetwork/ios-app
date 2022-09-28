import Foundation

struct TIPEphemeral {
    
    let type: String
    let deviceID: String
    let userID: String
    let seed: String
    let createdAt: String
    
}

extension TIPEphemeral: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case type
        case deviceID = "device_id"
        case userID = "user_id"
        case seed = "seed_base64"
        case createdAt = "created_at"
    }
    
}
