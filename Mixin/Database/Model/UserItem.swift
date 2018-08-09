import Foundation
import WCDBSwift

struct UserItem: BaseCodable {

    static var tableName: String = "users"

    let userId: String
    var fullName = ""
    let identityNumber: String
    var avatarUrl = ""
    var phone: String? = nil
    var isVerified = false
    var muteUntil: String? = nil
    var appId: String? = nil
    let createdAt: String?
    let relationship: String

    var role: String = ""
    var appDescription: String? = nil
    var appCreatorId: String? = nil

    enum CodingKeys: String, CodingTableKey {
        typealias Root = UserItem
        case userId = "user_id"
        case fullName = "full_name"
        case identityNumber = "identity_number"
        case avatarUrl = "avatar_url"
        case phone
        case isVerified = "is_verified"
        case muteUntil = "mute_until"
        case appId = "app_id"
        case relationship
        case createdAt = "created_at"
        case appDescription
        case appCreatorId
        case role

        static let objectRelationalMapping = TableBinding(CodingKeys.self)

    }

    var isMuted: Bool {
        guard let muteUntil = self.muteUntil else {
            return false
        }
        return muteUntil >= Date().toUTCString()
    }

    var isBot: Bool {
        guard let appId = self.appId else {
            return false
        }
        return !appId.isEmpty
    }
}

extension UserItem {

    static func createUser(userId: String, fullName: String, identityNumber: String, avatarUrl: String, appId: String?) -> UserItem {
        return UserItem(userId: userId, fullName: fullName, identityNumber: identityNumber, avatarUrl: avatarUrl, phone: nil, isVerified: false, muteUntil: nil, appId: appId, createdAt: nil, relationship: "", role: "", appDescription: nil, appCreatorId: nil)
    }

    static func createUser(from user: UserResponse) -> UserItem {
        return UserItem(userId: user.userId, fullName: user.fullName, identityNumber: user.identityNumber, avatarUrl: user.avatarUrl, phone: user.phone, isVerified: user.isVerified, muteUntil: user.muteUntil, appId: user.app?.appId, createdAt: user.createdAt, relationship: user.relationship.rawValue, role: "", appDescription: user.app?.description, appCreatorId: user.app?.creatorId)
    }

}
