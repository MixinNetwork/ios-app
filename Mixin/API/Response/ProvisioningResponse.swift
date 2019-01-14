import Foundation

struct ProvisioningResponse: Codable {
    
    let type: String
    let deviceId: String
    let description: String
    let secret: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case deviceId = "device_id"
        case description
        case secret
        case createdAt = "created_at"
    }
    
}
