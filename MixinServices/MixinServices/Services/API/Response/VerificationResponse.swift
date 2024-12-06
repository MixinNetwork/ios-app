import Foundation

public struct VerificationResponse {
    
    public let id: String
    public let hasEmergencyContact: Bool
    public let deactivation: Deactivation?
    
}

extension VerificationResponse: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case id
        case hasEmergencyContact = "has_emergency_contact"
        case deactivationRequestedAt = "deactivation_requested_at"
        case deactivationEffectiveAt = "deactivation_effective_at"
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let deactivationRequestedAt = try container.decodeIfPresent(String.self, forKey: .deactivationRequestedAt)
        let deactivationEffectiveAt = try container.decodeIfPresent(String.self, forKey: .deactivationEffectiveAt)
        
        self.id = try container.decode(String.self, forKey: .id)
        self.hasEmergencyContact = try container.decode(Bool.self, forKey: .hasEmergencyContact)
        self.deactivation = Deactivation(requestedAt: deactivationRequestedAt, effectiveAt: deactivationEffectiveAt)
    }
    
}
