import Foundation
import UIKit

public struct AuthorizationRequest: Codable {
    
    public let authorizationId: String
    public let scopes: [String]
    
    enum CodingKeys: String, CodingKey {
        case authorizationId = "authorization_id"
        case scopes
    }
    
    public init(authorizationId: String, scopes: [String]) {
        self.authorizationId = authorizationId
        self.scopes = scopes
    }
    
}
