import Foundation
import GRDB

public struct ParticipantUser {
    
    public let conversationId: String
    public let role: String
    public let userId: String
    public let userFullName: String
    public let userAvatarUrl: String
    public let userIdentityNumber: String
    
    public init(conversationId: String, role: String, userId: String, userFullName: String, userAvatarUrl: String, userIdentityNumber: String) {
        self.conversationId = conversationId
        self.role = role
        self.userId = userId
        self.userFullName = userFullName
        self.userAvatarUrl = userAvatarUrl
        self.userIdentityNumber = userIdentityNumber
    }
    
    public init(conversationId: String, user: UserResponse) {
        self.init(conversationId: conversationId,
                  role: "",
                  userId: user.userId,
                  userFullName: user.fullName,
                  userAvatarUrl: user.avatarUrl,
                  userIdentityNumber: user.identityNumber)
    }
    
    public init(conversationId: String, user: GroupUser) {
        self.init(conversationId: conversationId,
                  role: "",
                  userId: user.userId,
                  userFullName: user.fullName,
                  userAvatarUrl: user.avatarUrl,
                  userIdentityNumber: user.identityNumber)
    }
    
    public init(conversationId: String, account: Account) {
        self.init(conversationId: conversationId,
                  role: "",
                  userId: account.user_id,
                  userFullName: account.full_name,
                  userAvatarUrl: account.avatar_url,
                  userIdentityNumber: account.identity_number)
    }
    
}

extension ParticipantUser: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: CodingKey {
        case conversationId
        case role
        case userId
        case userFullName
        case userAvatarUrl
        case userIdentityNumber
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        conversationId = try container.decodeIfPresent(String.self, forKey: .conversationId) ?? ""
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? ""
        userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
        userFullName = try container.decodeIfPresent(String.self, forKey: .userFullName) ?? ""
        userAvatarUrl = try container.decodeIfPresent(String.self, forKey: .userAvatarUrl) ?? ""
        userIdentityNumber = try container.decodeIfPresent(String.self, forKey: .userIdentityNumber) ?? ""
    }
    
}
