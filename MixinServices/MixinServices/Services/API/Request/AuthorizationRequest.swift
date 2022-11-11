import Foundation

public struct AuthorizationRequest: Codable {
    
    public let authorizationId: String
    public let scopes: [String]
    public let pin: String?
    
    enum CodingKeys: String, CodingKey {
        case authorizationId = "authorization_id"
        case scopes
        case pin = "pin_base64"
    }
    
    public init(authorizationId: String, scopes: [String], pin: String?) {
        self.authorizationId = authorizationId
        self.scopes = scopes
        self.pin = pin
    }
    
}
