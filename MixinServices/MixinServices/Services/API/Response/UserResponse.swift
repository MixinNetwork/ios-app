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
    public let isScam: Bool
    public let isDeactivated: Bool?
    public let membership: User.Membership
    
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
        case isScam = "is_scam"
        case isDeactivated = "is_deactivated"
        case membership
    }
    
    public var deactivationIgnored: UserResponse {
        UserResponse(userId: userId,
                     fullName: fullName,
                     biography: biography,
                     relationship: relationship,
                     identityNumber: identityNumber,
                     avatarUrl: avatarUrl,
                     phone: phone,
                     isVerified: isVerified,
                     muteUntil: muteUntil,
                     createdAt: createdAt,
                     app: app,
                     isScam: isScam,
                     isDeactivated: nil,
                     membership: membership)
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
