import UIKit

public class MessagesWithUserSearchResult: MessagesWithinConversationSearchResult {
    
    let userId: String
    let userFullname: String
    
    init(conversationId: String, name: String, iconUrl: String, userId: String, userIsVerified: Bool, userAppId: String?, relatedMessageCount: Int, keyword: String) {
        self.userId = userId
        self.userFullname = name
        let badgeImage = SearchResult.userBadgeImage(isVerified: userIsVerified, appId: userAppId)
        super.init(conversationId: conversationId,
                   badgeImage: badgeImage,
                   name: name,
                   iconUrl: iconUrl,
                   relatedMessageCount: relatedMessageCount,
                   keyword: keyword)
    }
    
}
