import Foundation
import GRDB

public struct UserItem {
    
    public let userId: String
    public var fullName: String
    public var biography: String
    public let identityNumber: String
    public var avatarUrl: String
    public var phone: String?
    public var isVerified: Bool
    public var muteUntil: String?
    public var appId: String?
    public let createdAt: String?
    public var isScam: Bool
    public let isDeactivated: Bool
    public let relationship: String
    public var role: String
    public var appCreatorId: String?
    public let membership: User.Membership?
    
    internal init(
        userId: String, fullName: String, biography: String, identityNumber: String,
        avatarUrl: String, phone: String? = nil, isVerified: Bool,
        muteUntil: String? = nil, appId: String? = nil, createdAt: String?,
        isScam: Bool, isDeactivated: Bool, relationship: String, role: String,
        appCreatorId: String? = nil, membership: User.Membership?
    ) {
        self.userId = userId
        self.fullName = fullName
        self.biography = biography
        self.identityNumber = identityNumber
        self.avatarUrl = avatarUrl
        self.phone = phone
        self.isVerified = isVerified
        self.muteUntil = muteUntil
        self.appId = appId
        self.createdAt = createdAt
        self.isScam = isScam
        self.isDeactivated = isDeactivated
        self.relationship = relationship
        self.role = role
        self.appCreatorId = appCreatorId
        self.membership = membership
    }
    
}

extension UserItem: Decodable, MixinFetchableRecord {
    
    public enum CodingKeys: String, CodingKey {
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
        case isDeactivated = "is_deactivated"
        case appCreatorId
        case role
        case membership
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.userId = try container.decode(String.self, forKey: .userId)
        
        self.fullName = try container.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        self.biography = try container.decodeIfPresent(String.self, forKey: .biography) ?? ""
        self.identityNumber = try container.decodeIfPresent(String.self, forKey: .identityNumber) ?? "0"
        self.avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl) ?? ""
        
        self.phone = try container.decodeIfPresent(String.self, forKey: .phone)
        
        self.isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
        
        self.muteUntil = try container.decodeIfPresent(String.self, forKey: .muteUntil)
        self.appId = try container.decodeIfPresent(String.self, forKey: .appId)
        self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        
        self.isScam = try container.decodeIfPresent(Bool.self, forKey: .isScam) ?? false
        self.isDeactivated = try container.decodeIfPresent(Bool.self, forKey: .isDeactivated) ?? false
        
        self.relationship = try container.decodeIfPresent(String.self, forKey: .relationship) ?? Relationship.STRANGER.rawValue
        self.role = try container.decodeIfPresent(String.self, forKey: .role) ?? ""
        
        self.appCreatorId = try container.decodeIfPresent(String.self, forKey: .appCreatorId)
        self.membership = try container.decodeIfPresent(User.Membership.self, forKey: .membership)
    }
    
}

extension UserItem {
    
    public var isMuted: Bool {
        guard let muteUntil = self.muteUntil else {
            return false
        }
        return muteUntil >= Date().toUTCString()
    }
    
    public var isBot: Bool {
        guard let appId = self.appId else {
            return false
        }
        return !appId.isEmpty
    }
    
    public var isSelfBot: Bool {
        guard let appCreatorId = self.appCreatorId else {
            return false
        }
        return appCreatorId == myUserId
    }
    
    public var isCreatedByMessenger: Bool {
        return identityNumber != "0"
    }
    
    public var notificationUserInfo: [String: String] {
        var userInfo = [
            UNNotificationContent.UserInfoKey.ownerUserId: userId,
            UNNotificationContent.UserInfoKey.ownerUserFullname: fullName,
            UNNotificationContent.UserInfoKey.ownerUserIdentityNumber: identityNumber,
            UNNotificationContent.UserInfoKey.ownerUserAvatarUrl: avatarUrl,
        ]
        userInfo[UNNotificationContent.UserInfoKey.ownerUserAppId] = appId
        return userInfo
    }
    
    public static func createUser(
        userId: String, fullName: String, identityNumber: String,
        avatarUrl: String, appId: String?, membership: User.Membership?
    ) -> UserItem {
        UserItem(userId: userId,
                 fullName: fullName,
                 biography: "",
                 identityNumber: identityNumber,
                 avatarUrl: avatarUrl,
                 phone: nil,
                 isVerified: false,
                 muteUntil: nil,
                 appId: appId,
                 createdAt: nil,
                 isScam: false,
                 isDeactivated: false,
                 relationship: "",
                 role: "",
                 appCreatorId: nil,
                 membership: membership)
    }
    
    public static func createUser(from user: UserResponse) -> UserItem {
        UserItem(userId: user.userId,
                 fullName: user.fullName,
                 biography: user.biography,
                 identityNumber: user.identityNumber,
                 avatarUrl: user.avatarUrl,
                 phone: user.phone,
                 isVerified: user.isVerified,
                 muteUntil: user.muteUntil,
                 appId: user.app?.appId,
                 createdAt: user.createdAt,
                 isScam: user.isScam,
                 isDeactivated: user.isDeactivated ?? false,
                 relationship: user.relationship.rawValue,
                 role: "",
                 appCreatorId: user.app?.creatorId,
                 membership: user.membership)
    }
    
    public static func createUser(from user: User) -> UserItem {
        UserItem(userId: user.userId,
                 fullName: user.fullName ?? "",
                 biography: user.biography ?? "",
                 identityNumber: user.identityNumber,
                 avatarUrl: user.avatarUrl ?? "",
                 phone: user.phone,
                 isVerified: user.isVerified ?? false,
                 muteUntil: user.muteUntil,
                 appId: user.appId ?? "",
                 createdAt: user.createdAt,
                 isScam: user.isScam,
                 isDeactivated: user.isDeactivated,
                 relationship: user.relationship,
                 role: "",
                 appCreatorId: user.app?.creatorId,
                 membership: user.membership)
    }
    
    public static func createUser(from account: Account) -> UserItem {
        UserItem(userId: account.userID,
                 fullName: account.fullName,
                 biography: account.biography,
                 identityNumber: account.identityNumber,
                 avatarUrl: account.avatarURL,
                 phone: account.phone,
                 isVerified: false,
                 muteUntil: nil,
                 appId: nil,
                 createdAt: account.createdAt,
                 isScam: false,
                 isDeactivated: false,
                 relationship: "",
                 role: "",
                 appCreatorId: nil,
                 membership: account.membership)
    }
    
    public static func makeUserItem(notificationUserInfo userInfo: [AnyHashable: Any]) -> UserItem? {
        guard let userId = userInfo[UNNotificationContent.UserInfoKey.ownerUserId] as? String else {
            return nil
        }
        guard let fullName = userInfo[UNNotificationContent.UserInfoKey.ownerUserFullname] as? String else {
            return nil
        }
        guard let identityNumber = userInfo[UNNotificationContent.UserInfoKey.ownerUserIdentityNumber] as? String else {
            return nil
        }
        guard let avatarUrl = userInfo[UNNotificationContent.UserInfoKey.ownerUserAvatarUrl] as? String else {
            return nil
        }
        let appId = userInfo[UNNotificationContent.UserInfoKey.ownerUserAppId] as? String
        return UserItem.createUser(userId: userId, fullName: fullName, identityNumber: identityNumber, avatarUrl: avatarUrl, appId: appId, membership: nil)
    }
    
    public func matches(lowercasedKeyword keyword: String) -> Bool {
        return fullName.lowercased().contains(keyword)
            || identityNumber.contains(keyword)
            || (phone?.contains(keyword) ?? false)
    }
    
}
