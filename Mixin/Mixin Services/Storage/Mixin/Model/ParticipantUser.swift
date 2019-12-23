import WCDBSwift

struct ParticipantUser: TableCodable {

    public let conversationId: String
    public let role: String
    public let userId: String
    public let userFullName: String
    public let userAvatarUrl: String
    public let userIdentityNumber: String

    enum CodingKeys: String, CodingTableKey {
        typealias Root = ParticipantUser
        case userId
        case userIdentityNumber
        case userFullName
        case userAvatarUrl
        case role
        case conversationId
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
    }
}

extension ParticipantUser {

    static public func createParticipantUser(conversationId: String, user: UserResponse) -> ParticipantUser {
        return ParticipantUser(conversationId: conversationId, role: "", userId: user.userId, userFullName: user.fullName, userAvatarUrl: user.avatarUrl, userIdentityNumber: user.identityNumber)
    }

    static public func createParticipantUser(conversationId: String, user: GroupUser) -> ParticipantUser {
        return ParticipantUser(conversationId: conversationId, role: "", userId: user.userId, userFullName: user.fullName, userAvatarUrl: user.avatarUrl, userIdentityNumber: user.identityNumber)
    }

    static public func createParticipantUser(conversationId: String, account: Account) -> ParticipantUser {
        return ParticipantUser(conversationId: conversationId, role: "", userId: account.user_id, userFullName: account.full_name, userAvatarUrl: account.avatar_url, userIdentityNumber: account.identity_number)
    }
}
