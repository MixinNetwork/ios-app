import Foundation
import MixinServices

struct DeviceTransferUser {
    
    let userId: String
    let fullName: String?
    let biography: String?
    let identityNumber: String
    let avatarUrl: String?
    let phone: String?
    let isVerified: Bool
    let muteUntil: String?
    let appId: String?
    let createdAt: String?
    let relationship: String
    let isScam: Bool?
    
    init(user: User) {
        userId = user.userId
        fullName = user.fullName
        biography = user.biography ?? ""
        identityNumber = user.identityNumber
        avatarUrl = user.avatarUrl
        phone = user.phone
        isVerified = user.isVerified
        muteUntil = user.muteUntil
        appId = user.appId
        createdAt = user.createdAt
        relationship = user.relationship
        isScam = user.isScam
    }
    
    func toUser() -> User {
        User(userId: userId,
             fullName: fullName,
             biography: biography,
             identityNumber: identityNumber,
             avatarUrl: avatarUrl,
             phone: phone,
             isVerified: isVerified,
             muteUntil: muteUntil,
             appId: appId,
             createdAt: createdAt,
             relationship: relationship,
             isScam: isScam ?? false)
    }
    
}

extension DeviceTransferUser: Codable {
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case fullName = "full_name"
        case biography = "biography"
        case identityNumber = "identity_number"
        case avatarUrl = "avatar_url"
        case phone
        case isVerified = "is_verified"
        case muteUntil = "mute_until"
        case appId = "app_id"
        case relationship
        case createdAt = "created_at"
        case isScam = "is_scam"
    }
    
}
