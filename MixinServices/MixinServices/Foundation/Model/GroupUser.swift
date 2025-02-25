import Foundation

public class GroupUser: NSObject {
    
    public let userId: String
    public let identityNumber: String
    public let fullName: String
    public let avatarUrl: String
    public let isVerified: Bool
    public let isBot: Bool
    
    public init(user: UserItem) {
        self.userId = user.userId
        self.identityNumber = user.identityNumber
        self.fullName = user.fullName
        self.avatarUrl = user.avatarUrl
        self.isVerified = user.isVerified
        self.isBot = user.isBot
        super.init()
    }
    
}
