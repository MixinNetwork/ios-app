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
    public let isDeactivated: Bool
    public let membership: User.Membership?
    
    public var app: App?
    
    public init(
        userId: String, fullName: String?, biography: String?, identityNumber: String,
        avatarUrl: String?, phone: String? = nil, isVerified: Bool,
        muteUntil: String? = nil, appId: String? = nil, createdAt: String?,
        relationship: String, isScam: Bool, isDeactivated: Bool,
        membership: User.Membership?, app: App? = nil
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
        self.relationship = relationship
        self.isScam = isScam
        self.isDeactivated = isDeactivated
        self.membership = membership
        self.app = app
    }
    
    public static func createSystemUser() -> User {
        User(userId: systemUser,
             fullName: "0",
             biography: "",
             identityNumber: "0",
             avatarUrl: nil,
             phone: nil,
             isVerified: false,
             muteUntil: nil,
             appId: nil,
             createdAt: nil,
             relationship: "",
             isScam: false,
             isDeactivated: false,
             membership: nil,
             app: nil)
    }
    
    public static func createUser(from user: UserResponse) -> User {
        User(userId: user.userId,
             fullName: user.fullName,
             biography: user.biography,
             identityNumber: user.identityNumber,
             avatarUrl: user.avatarUrl,
             phone: user.phone,
             isVerified: user.isVerified,
             muteUntil: user.muteUntil,
             appId: user.app?.appId,
             createdAt: user.createdAt,
             relationship: user.relationship.rawValue,
             isScam: user.isScam,
             isDeactivated: user.isDeactivated ?? false,
             membership: user.membership, 
             app: user.app)
    }

    public static func createUser(from account: Account) -> User {
        User(userId: account.userID,
             fullName: account.fullName,
             biography: account.biography,
             identityNumber: account.identityNumber,
             avatarUrl: account.avatarURL,
             phone: account.phone,
             isVerified: false,
             muteUntil: nil,
             appId: nil,
             createdAt: account.createdAt,
             relationship: Relationship.ME.rawValue,
             isScam: false,
             isDeactivated: false,
             membership: account.membership,
             app: nil)
    }
    
    public func matches(lowercasedKeyword keyword: String) -> Bool {
        let fullnameMatches: Bool
        if let fullName {
            fullnameMatches = fullName.lowercased().contains(keyword)
        } else {
            fullnameMatches = false
        }
        return fullnameMatches || identityNumber.contains(keyword)
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
        case isDeactivated = "is_deactivated"
        case membership
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
        self.isDeactivated = try container.decodeIfPresent(Bool.self, forKey: .isDeactivated) ?? false
        
        self.membership = try container.decodeIfPresent(User.Membership.self, forKey: .membership)
    }
    
}

extension User: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "users"
    
}

extension User {
    
    public struct Membership: Codable, DatabaseValueConvertible {
        
        public enum Plan: String, Codable {
            case none
            case advance
            case elite
            case prosperity
        }
        
        public enum CodingKeys: String, CodingKey {
            case plan
            case expiredAt = "expired_at"
        }
        
        public let plan: Plan
        public let expiredAt: Date
        
        public var databaseValue: DatabaseValue {
            if let data = try? JSONEncoder.default.encode(self),
               let string = String(data: data, encoding: .utf8)
            {
                string.databaseValue
            } else {
                .null
            }
        }
        
        public init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
            let expiredAt = try container.decode(String.self, forKey: .expiredAt)
            self.plan = try container.decode(User.Membership.Plan.self, forKey: .plan)
            self.expiredAt = DateFormatter.iso8601Full.date(from: expiredAt) ?? .distantPast
        }
        
        public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> User.Membership? {
            guard 
                let string = String.fromDatabaseValue(dbValue),
                let data = string.data(using: .utf8),
                let object = try? JSONDecoder.default.decode(Self.self, from: data)
            else {
                return nil
            }
            return object
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(plan, forKey: .plan)
            try container.encode(expiredAt.toUTCString(), forKey: .expiredAt)
        }
        
    }
    
}
