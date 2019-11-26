import Foundation
import WCDBSwift

struct UserItem: BaseCodable {

    static var tableName: String = "users"

    let userId: String
    var fullName = ""
    var biography = ""
    let identityNumber: String
    var avatarUrl = ""
    var phone: String? = nil
    var isVerified = false
    var muteUntil: String? = nil
    var appId: String? = nil
    let createdAt: String?
    let relationship: String

    var role: String = ""
    var appCreatorId: String? = nil

    enum CodingKeys: String, CodingTableKey {
        typealias Root = UserItem
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

    var isSelfBot: Bool {
        guard let appCreatorId = self.appCreatorId else {
            return false
        }
        return appCreatorId == AccountAPI.shared.accountUserId
    }
    
    var isCreatedByMessenger: Bool {
        return identityNumber != "0"
    }
    
    func matches(lowercasedKeyword keyword: String) -> Bool {
        return fullName.lowercased().contains(keyword)
            || identityNumber.contains(keyword)
            || (phone?.contains(keyword) ?? false)
    }
    
}

extension UserItem {

    static func createUser(userId: String, fullName: String, identityNumber: String, avatarUrl: String, appId: String?) -> UserItem {
        return UserItem(userId: userId, fullName: fullName, biography: "", identityNumber: identityNumber, avatarUrl: avatarUrl, phone: nil, isVerified: false, muteUntil: nil, appId: appId, createdAt: nil, relationship: "", role: "", appCreatorId: nil)
    }

    static func createUser(from user: UserResponse) -> UserItem {
        return UserItem(userId: user.userId, fullName: user.fullName, biography: user.biography, identityNumber: user.identityNumber, avatarUrl: user.avatarUrl, phone: user.phone, isVerified: user.isVerified, muteUntil: user.muteUntil, appId: user.app?.appId, createdAt: user.createdAt, relationship: user.relationship.rawValue, role: "", appCreatorId: user.app?.creatorId)
    }

    static func createUser(from user: User) -> UserItem {
        return UserItem(userId: user.userId, fullName: user.fullName ?? "", biography: user.biography ?? "", identityNumber: user.identityNumber, avatarUrl: user.avatarUrl ?? "", phone: user.phone, isVerified: user.isVerified ?? false, muteUntil: user.muteUntil, appId: user.appId ?? "", createdAt: user.createdAt, relationship: user.relationship, role: "", appCreatorId: user.app?.creatorId)
    }

    static func createUser(from account: Account) -> UserItem {
        return UserItem(userId: account.user_id, fullName: account.full_name, biography: account.biography, identityNumber: account.identity_number, avatarUrl: account.avatar_url, phone: account.phone, isVerified: false, muteUntil: nil, appId: nil, createdAt: account.created_at, relationship: "", role: "", appCreatorId: nil)
    }

}
