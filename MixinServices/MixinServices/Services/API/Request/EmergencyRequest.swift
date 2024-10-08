import Foundation

public struct EmergencyRequest: Encodable {
    
    enum Purpose: String, Encodable {
        case contact = "CONTACT"
        case session = "SESSION"
    }
    
    enum CodingKeys: String, CodingKey {
        case phone
        case identityNumber = "identity_number"
        case pin = "pin_base64"
        case code
        case purpose
    }
    
    let phone: String?
    let identityNumber: String?
    let pin: String?
    let code: String?
    let purpose: Purpose
    
}
