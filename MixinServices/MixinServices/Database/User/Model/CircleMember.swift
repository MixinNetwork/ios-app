import UIKit
import GRDB

public final class CircleMember {
    
    public let conversationId: String
    public let userId: String?
    public let category: String
    public let name: String
    public let iconUrl: String
    public let identityNumber: String?
    public let phoneNumber: String?
    public let isVerified: Bool?
    public let appID: String?
    public let membership: User.Membership?
    
    public func matches(lowercasedKeyword keyword: String) -> Bool {
        name.lowercased().contains(keyword)
            || (identityNumber?.contains(keyword) ?? false)
            || (phoneNumber?.contains(keyword) ?? false)
    }
    
    public init(
        conversationId: String, userId: String?, category: String,
        name: String, iconUrl: String, identityNumber: String?,
        phoneNumber: String?, isVerified: Bool?, appID: String?,
        membership: User.Membership?
    ) {
        self.conversationId = conversationId
        self.userId = userId
        self.category = category
        self.name = name
        self.iconUrl = iconUrl
        self.identityNumber = identityNumber
        self.phoneNumber = phoneNumber
        self.isVerified = isVerified
        self.appID = appID
        self.membership = membership
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId) ?? ""
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        iconUrl = try container.decodeIfPresent(String.self, forKey: .iconUrl) ?? ""
        identityNumber = try container.decodeIfPresent(String.self, forKey: .identityNumber)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified)
        appID = try container.decodeIfPresent(String.self, forKey: .appID)
        membership = try container.decodeIfPresent(User.Membership.self, forKey: .membership)
    }
    
}

extension CircleMember: Equatable {
    
    public static func == (lhs: CircleMember, rhs: CircleMember) -> Bool {
        lhs.conversationId == rhs.conversationId
    }
    
}

extension CircleMember: Hashable {
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(conversationId)
    }
    
}

extension CircleMember: Decodable, MixinFetchableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case userId = "user_id"
        case category
        case name
        case iconUrl = "icon_url"
        case identityNumber = "identity_number"
        case phoneNumber = "phone"
        case isVerified = "is_verified"
        case appID = "app_id"
        case membership
    }
    
}

