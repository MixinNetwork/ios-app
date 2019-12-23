import Foundation

public struct VerificationResponse: Codable {

    public let type: String
    public let id: String
    public let hasEmergencyContact: Bool

    enum CodingKeys: String, CodingKey {
        case type
        case id
        case hasEmergencyContact = "has_emergency_contact"
    }
    
}
