import Foundation

public struct AuthorizationResponse: Codable {
    
    public let authorizationId: String
    public let authorizationCode: String
    public let scopes: [String]
    public let codeId: String
    public let createdAt: String
    public let accessedAt: String
    public let app: App
    
    enum CodingKeys: String, CodingKey {
        case authorizationId = "authorization_id"
        case authorizationCode = "authorization_code"
        case scopes
        case codeId = "code_id"
        case createdAt = "created_at"
        case accessedAt = "accessed_at"
        case app
    }
    
}
