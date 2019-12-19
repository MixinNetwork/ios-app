import Foundation

public struct VerificationResponse: Codable {

    let type: String
    let id: String
    let hasEmergencyContact: Bool

    enum CodingKeys: String, CodingKey {
        case type
        case id
        case hasEmergencyContact = "has_emergency_contact"
    }
    
}
