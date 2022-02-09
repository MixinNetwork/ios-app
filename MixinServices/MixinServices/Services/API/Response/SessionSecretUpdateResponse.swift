import Foundation

public struct SessionSecretUpdateResponse: Decodable {
    
    public let pinToken: String
    
    enum CodingKeys: String, CodingKey {
        case pinToken = "pin_token"
    }
    
}
