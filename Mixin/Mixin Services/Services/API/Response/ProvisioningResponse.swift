import Foundation

public struct ProvisioningResponse: Codable {
    
    public let type: String
    public let deviceId: String
    public let description: String
    public let secret: String
    public let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case deviceId = "device_id"
        case description
        case secret
        case createdAt = "created_at"
    }
    
}
