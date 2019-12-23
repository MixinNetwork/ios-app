import UIKit

public class MessagesWithinConversationSearchResult: SearchResult {
    
    let conversationId: String
    
    private let name: String
    private let relatedMessageCount: Int
    private let keyword: String
    
    init(conversationId: String, badgeImage: UIImage?, name: String, iconUrl: String, relatedMessageCount: Int, keyword: String) {
        self.conversationId = conversationId
        self.name = name
        self.relatedMessageCount = relatedMessageCount
        self.keyword = keyword
        super.init(iconUrl: iconUrl,
                   badgeImage: badgeImage,
                   superscript: nil)
    }
    
    override func updateTitleAndDescription() {
        title = SearchResult.attributedText(text: name,
                                            textAttributes: SearchResult.titleAttributes,
                                            keyword: keyword,
                                            keywordAttributes: SearchResult.highlightedTitleAttributes)
        let desc = "\(relatedMessageCount)" + R.string.localizable.search_related_messages_count()
        description = NSAttributedString(string: desc, attributes: SearchResult.normalDescriptionAttributes)
    }
    
}
