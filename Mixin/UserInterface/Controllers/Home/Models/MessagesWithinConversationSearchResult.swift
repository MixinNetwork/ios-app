import UIKit

class MessagesWithinConversationSearchResult: SearchResult {
    
    let conversationId: String
    
    init(conversationId: String, badgeImage: UIImage?, name: String, iconUrl: String, relatedMessageCount: Int, keyword: String) {
        self.conversationId = conversationId
        let title = SearchResult.attributedText(text: name,
                                                textAttributes: SearchResult.titleAttributes,
                                                keyword: keyword,
                                                keywordAttributes: SearchResult.highlightedTitleAttributes)
        let desc = "\(relatedMessageCount)" + R.string.localizable.search_related_messages_count()
        let description = NSAttributedString(string: desc, attributes: SearchResult.normalDescriptionAttributes)
        super.init(iconUrl: iconUrl,
                   title: title,
                   badgeImage: badgeImage,
                   superscript: nil, description: description)
    }
    
}
