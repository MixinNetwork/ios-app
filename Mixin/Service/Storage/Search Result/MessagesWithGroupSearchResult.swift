import UIKit

final class MessagesWithGroupSearchResult: MessagesWithinConversationSearchResult {
    
    init(
        conversationId: String,
        name: String,
        iconUrl: String,
        relatedMessageCount: Int,
        keyword: String
    ) {
        super.init(
            conversationId: conversationId,
            badgeImage: R.image.group_indicator_small(),
            name: name,
            iconUrl: iconUrl,
            relatedMessageCount: relatedMessageCount,
            keyword: keyword
        )
    }
    
}
