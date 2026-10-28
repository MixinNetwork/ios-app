import UIKit
import MixinServices

class ConversationSearchResult: SearchResult {
    
    let conversation: ConversationItem
    
    private let keyword: String
    
    init(conversation: ConversationItem, keyword: String) {
        self.conversation = conversation
        self.keyword = keyword
        let badgeImage: UIImage? = if conversation.isGroup() {
            R.image.group_indicator_small()
        } else {
            nil
        }
        super.init(
            iconUrl: conversation.iconUrl,
            badgeImage: badgeImage,
            superscript: nil
        )
    }
    
    override func updateTitleAndDescription() {
        title = SearchResult.attributedText(text: conversation.getConversationName(),
                                            textAttributes: SearchResult.titleAttributes,
                                            keyword: keyword,
                                            keywordAttributes: SearchResult.highlightedTitleAttributes)
    }
    
}
