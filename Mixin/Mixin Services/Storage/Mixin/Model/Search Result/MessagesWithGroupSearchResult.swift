import UIKit

public class MessagesWithGroupSearchResult: MessagesWithinConversationSearchResult {
    
    init(conversationId: String, name: String, iconUrl: String, relatedMessageCount: Int, keyword: String) {
        super.init(conversationId: conversationId,
                   badgeImage: nil,
                   name: name,
                   iconUrl: iconUrl,
                   relatedMessageCount: relatedMessageCount,
                   keyword: keyword)
    }
    
}
