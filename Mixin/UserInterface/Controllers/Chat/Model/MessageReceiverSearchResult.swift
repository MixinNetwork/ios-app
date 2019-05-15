import UIKit

class MessageReceiverSearchResult: SearchResult {
    
    let receiver: MessageReceiver
    
    init(receiver: MessageReceiver, keyword: String) {
        self.receiver = receiver
        let iconUrl: String
        let description: NSAttributedString?
        switch receiver.item {
        case let .group(conversation):
            iconUrl = conversation.iconUrl
            description = nil
        case let .user(user):
            iconUrl = user.avatarUrl
            description = SearchResult.description(user: user, keyword: keyword)
        }
        let title = SearchResult.attributedText(text: receiver.name,
                                                textAttributes: SearchResult.titleAttributes,
                                                keyword: keyword,
                                                keywordAttributes: SearchResult.highlightedTitleAttributes)
        super.init(iconUrl: iconUrl,
                   title: title,
                   badgeImage: receiver.badgeImage,
                   superscript: nil,
                   description: description)
    }
    
}
