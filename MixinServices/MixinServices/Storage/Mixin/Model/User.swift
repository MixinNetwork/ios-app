import Foundation
import GRDB

public struct User {
    
    static let systemUser = "00000000-0000-0000-0000-000000000000"
    
    public let userId: String
    public let fullName: String?
    public let biography: String?
    public let identityNumber: String
    public let avatarUrl: String?
    public var phone: String?
    public var isVerified: Bool
    public var muteUntil: String?
    public var appId: String?
    public let createdAt: String?
    public let relationship: String
    public var isScam: Bool
    
    public var app: App?
    
    internal init(userId: String, fullName: String?, biography: String?, identityNumber: String, avatarUrl: String?, phone: String? = nil, isVerified: Bool, muteUntil: String? = nil, appId: String? = nil, createdAt: String?, relationship: String, isScam: Bool, app: App? = nil) {
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
        self.relationship = relationship
        self.isScam = isScam
        self.app = app
    }
    
    public static func createSystemUser() -> User {
        return User(userId: systemUser, fullName: "0", biography: "", identityNumber: "0", avatarUrl: nil, phone: nil, isVerified: false, muteUntil: nil, appId: nil, createdAt: nil, relationship: "", isScam: false, app: nil)
    }
    
    public static func createUser(from user: UserResponse) -> User {
        return User(userId: user.userId, fullName: user.fullName, biography: user.biography, identityNumber: user.identityNumber, avatarUrl: user.avatarUrl, phone: user.phone, isVerified: user.isVerified, muteUntil: user.muteUntil, appId: user.app?.appId, createdAt: user.createdAt, relationship: user.relationship.rawValue, isScam: user.isScam, app: user.app)
    }

    public static func createUser(from account: Account) -> User {
        return User(userId: account.user_id, fullName: account.full_name, biography: account.biography, identityNumber: account.identity_number, avatarUrl: account.avatar_url, phone: account.phone, isVerified: false, muteUntil: nil, appId: nil, createdAt: account.created_at, relationship: Relationship.ME.rawValue, isScam: false, app: nil)
    }
    
}

extension User: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {

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
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.userId = try container.decode(String.self, forKey: .userId)
        
        self.fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
        self.biography = try container.decodeIfPresent(String.self, forKey: .biography)
        
        self.identityNumber = try container.decodeIfPresent(String.self, forKey: .identityNumber) ?? "0"
        
        self.avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        self.phone = try container.decodeIfPresent(String.self, forKey: .phone)
        
        self.isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
        
        self.muteUntil = try container.decodeIfPresent(String.self, forKey: .muteUntil)
        self.appId = try container.decodeIfPresent(String.self, forKey: .appId)
        self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        
        self.relationship = try container.decodeIfPresent(String.self, forKey: .relationship) ?? Relationship.STRANGER.rawValue
        
        self.isScam = try container.decodeIfPresent(Bool.self, forKey: .isScam) ?? false
    }
    
}

extension User: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "users"
    
}
