import UIKit

struct SessionSecretUpdateResponse: Decodable {
    
    let pinToken: String
    
    enum CodingKeys: String, CodingKey {
        case pinToken = "pin_token"
    }
    
}
