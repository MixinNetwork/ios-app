import Foundation

struct UserResponse: Codable {

    let userId: String
    let fullName: String
    let relationship: Relationship
    let identityNumber: String
    let avatarUrl: String
    let phone: String?
    let isVerified: Bool
    let muteUntil: String?
    let createdAt: String
    let app: App?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case fullName = "full_name"
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

enum Relationship: String, Codable {
    case ME
    case FRIEND
    case STRANGER
    case BLOCKING

    init(from decoder: Decoder) throws {
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


