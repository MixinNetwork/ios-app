import UIKit

struct SessionSecretUpdateResponse: Decodable {
    
    let serverPublicKey: String
    
    enum CodingKeys: String, CodingKey {
        case serverPublicKey = "server_public_key"
    }
    
}
