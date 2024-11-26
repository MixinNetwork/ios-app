import Foundation

public struct VerificationResponse: Codable {
    
    public let id: String
    public let hasEmergencyContact: Bool
    public let deactivatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case hasEmergencyContact = "has_emergency_contact"
        case deactivatedAt = "deactivated_at"
    }
    
}
