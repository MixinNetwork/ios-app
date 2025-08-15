import Foundation

public struct GroupMemberCandidate {
    
    public let userId: String
    public let identityNumber: String
    public let userFullName: String
    public let userAvatarUrl: String
    
    public init(user: UserItem) {
        self.userId = user.userId
        self.identityNumber = user.identityNumber
        self.userFullName = user.fullName
        self.userAvatarUrl = user.avatarUrl
    }
    
    public init(account: Account) {
        self.userId = account.userID
        self.identityNumber = account.identityNumber
        self.userFullName = account.fullName
        self.userAvatarUrl = account.avatarURL
    }
    
}
