import Foundation

struct TIPSecretReadRequest: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case action
        case signature = "signature_base64"
        case timestamp
    }
    
    let action = "READ"
    let signature: String
    let timestamp: UInt64
    
}
