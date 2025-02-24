import UIKit
import MixinServices

class MessagesWithUserSearchResult: MessagesWithinConversationSearchResult {
    
    let userId: String
    let userFullname: String
    
    init(
        conversationId: String, name: String, iconUrl: String, userId: String,
        userIsVerified: Bool, userIdentityNumber: String?,
        userMembership: User.Membership?, relatedMessageCount: Int,
        keyword: String
    ) {
        self.userId = userId
        self.userFullname = name
        let badgeImage = UserBadgeIcon.image(
            membership: userMembership,
            isVerified: userIsVerified,
            identityNumber: userIdentityNumber
        )
        super.init(conversationId: conversationId,
                   badgeImage: badgeImage,
                   name: name,
                   iconUrl: iconUrl,
                   relatedMessageCount: relatedMessageCount,
                   keyword: keyword)
    }
    
}
