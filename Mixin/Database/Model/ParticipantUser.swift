import WCDBSwift

struct ParticipantUser: TableCodable {

    let conversationId: String
    let role: String
    let userId: String
    let userFullName: String
    let userAvatarUrl: String
    let userIdentityNumber: String

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

    static func createParticipantUser(conversationId: String, user: UserResponse) -> ParticipantUser {
        return ParticipantUser(conversationId: conversationId, role: "", userId: user.userId, userFullName: user.fullName, userAvatarUrl: user.avatarUrl, userIdentityNumber: user.identityNumber)
    }

    static func createParticipantUser(conversationId: String, user: GroupUser) -> ParticipantUser {
        return ParticipantUser(conversationId: conversationId, role: "", userId: user.userId, userFullName: user.fullName, userAvatarUrl: user.avatarUrl, userIdentityNumber: user.identityNumber)
    }

    static func createParticipantUser(conversationId: String, account: Account) -> ParticipantUser {
        return ParticipantUser(conversationId: conversationId, role: "", userId: account.user_id, userFullName: account.full_name, userAvatarUrl: account.avatar_url, userIdentityNumber: account.identity_number)
    }
}
