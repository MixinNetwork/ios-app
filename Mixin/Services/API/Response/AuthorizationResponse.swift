import Foundation

struct AuthorizationResponse: Codable {

    let authorizationId: String
    let authorizationCode: String
    let scopes: [String]
    let codeId: String
    let app: App

    enum CodingKeys: String, CodingKey {
        case authorizationId = "authorization_id"
        case authorizationCode = "authorization_code"
        case scopes
        case codeId = "code_id"
        case app
    }
}
