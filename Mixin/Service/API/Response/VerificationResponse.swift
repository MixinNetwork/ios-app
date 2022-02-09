import Foundation

struct VerificationResponse: Codable {

    let type: String
    let id: String
    let hasEmergencyContact: Bool
    let deactivatedAt: String?

    enum CodingKeys: String, CodingKey {
        case type
        case id
        case hasEmergencyContact = "has_emergency_contact"
        case deactivatedAt = "deactivated_at"
    }
    
}
