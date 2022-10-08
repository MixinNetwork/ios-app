import UIKit
import MixinServices

class MessageReceiverSearchResult: SearchResult {
    
    let receiver: MessageReceiver
    
    private let keyword: String
    
    init(receiver: MessageReceiver, keyword: String) {
        self.receiver = receiver
        self.keyword = keyword
        let iconUrl: String
        switch receiver.item {
        case let .group(conversation):
            iconUrl = conversation.iconUrl
        case let .user(user):
            iconUrl = user.avatarUrl
        }
        super.init(iconUrl: iconUrl,
                   badgeImage: receiver.badgeImage,
                   superscript: nil)
    }
    
    override func updateTitleAndDescription() {
        title = SearchResult.attributedText(text: receiver.name,
                                            textAttributes: SearchResult.titleAttributes,
                                            keyword: keyword,
                                            keywordAttributes: SearchResult.highlightedTitleAttributes)
        if let content = receiver.conversationContent {
            description = SearchResult.description(conversationContent: content)
        } else if case let .user(user) = receiver.item {
            description = SearchResult.description(identityNumber: user.identityNumber, phoneNumber: user.phone, keyword: keyword)
        }
    }
    
}
