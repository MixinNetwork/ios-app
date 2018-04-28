import Foundation
import UIKit

struct AuthorizationRequest: Codable {

    let authorizationId: String
    let scopes: [String]


    enum CodingKeys: String, CodingKey {
        case authorizationId = "authorization_id"
        case scopes
    }
}

