import UIKit

class ConversationSearchResult: SearchResult {
    
    let conversation: ConversationItem
    
    init(conversation: ConversationItem, keyword: String) {
        self.conversation = conversation
        let title = SearchResult.attributedText(text: conversation.getConversationName(),
                                                textAttributes: SearchResult.titleAttributes,
                                                keyword: keyword,
                                                keywordAttributes: SearchResult.highlightedTitleAttributes)
        super.init(iconUrl: conversation.iconUrl,
                   title: title,
                   badgeImage: nil,
                   superscript: nil,
                   description: nil)
    }
    
}
