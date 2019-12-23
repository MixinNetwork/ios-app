import Foundation

public struct UserResponse: Codable {
    
    public let userId: String
    public let fullName: String
    public let biography: String
    public let relationship: Relationship
    public let identityNumber: String
    public let avatarUrl: String
    public let phone: String?
    public let isVerified: Bool
    public let muteUntil: String?
    public let createdAt: String
    public let app: App?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case fullName = "full_name"
        case biography = "biography"
        case relationship
        case identityNumber = "identity_number"
        case avatarUrl = "avatar_url"
        case phone
        case isVerified = "is_verified"
        case muteUntil = "mute_until"
        case createdAt = "created_at"
        case app
    }
    
}

public enum Relationship: String, Codable {
    
    case ME
    case FRIEND
    case STRANGER
    case BLOCKING
    
    public init(from decoder: Decoder) throws {
        let relationship = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        switch relationship {
        case "ME":
            self = .ME
        case "FRIEND":
            self = .FRIEND
        case "STRANGER":
            self = .STRANGER
        case "BLOCKING":
            self = .BLOCKING
        default:
            self = .STRANGER
        }
    }
    
}

public extension UserResponse {
    
    static func createUser(account: Account) -> UserResponse {
        return UserResponse(userId: account.user_id, fullName: account.full_name, biography: account.biography, relationship: Relationship.ME, identityNumber: account.identity_number, avatarUrl: account.avatar_url, phone: account.phone, isVerified: false, muteUntil: nil, createdAt: account.created_at, app: nil)
    }
    
}
