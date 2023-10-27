import Foundation

struct PINRequest {
    
    let pin: String
    let oldPIN: String?
    let salt: String?
    let oldSalt: String?
    let timestamp: UInt64?
    
}

extension PINRequest: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case pin = "pin_base64"
        case oldPIN = "old_pin_base64"
        case salt
        case oldSalt = "old_salt"
        case timestamp
    }
    
}
