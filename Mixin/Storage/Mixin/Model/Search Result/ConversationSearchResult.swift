import UIKit

public class ConversationSearchResult: SearchResult {
    
    let conversation: ConversationItem
    
    private let keyword: String
    
    init(conversation: ConversationItem, keyword: String) {
        self.conversation = conversation
        self.keyword = keyword
        super.init(iconUrl: conversation.iconUrl,
                   badgeImage: nil,
                   superscript: nil)
    }
    
    override func updateTitleAndDescription() {
        title = SearchResult.attributedText(text: conversation.getConversationName(),
                                            textAttributes: SearchResult.titleAttributes,
                                            keyword: keyword,
                                            keywordAttributes: SearchResult.highlightedTitleAttributes)
    }
    
}
