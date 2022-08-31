import Foundation

struct TIPSecretUpdateRequest: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case action
        case seed = "seed_base64"
        case secret = "secret_base64"
        case signature = "signature_base64"
        case timestamp
    }
    
    let action = "UPDATE"
    let seed: String
    let secret: String
    let signature: String
    let timestamp: UInt64
    
}
