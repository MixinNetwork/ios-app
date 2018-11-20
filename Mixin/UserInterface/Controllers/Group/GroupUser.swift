import Foundation

class GroupUser: NSObject {
    
    let userId: String
    let identityNumber: String
    @objc let fullName: String
    let avatarUrl: String
    let isVerified: Bool
    let isBot: Bool
    
    init(userId: String, identityNumber: String, fullName: String, avatarUrl: String, isVerified: Bool, isBot: Bool) {
        self.userId = userId
        self.identityNumber = identityNumber
        self.fullName = fullName
        self.avatarUrl = avatarUrl
        self.isVerified = isVerified
        self.isBot = isBot
    }

}
