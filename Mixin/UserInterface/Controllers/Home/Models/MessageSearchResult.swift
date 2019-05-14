import UIKit

class MessageSearchResult: SearchResult {
    
    let conversationId: String
    let messageId: String
    let isData: Bool
    let userId: String
    let userFullname: String
    let createdAt: String
    
    init(conversationId: String, messageId: String, category: String, content: String, createdAt: String, userId: String, fullname: String, avatarUrl: String, isVerified: Bool, appId: String?, keyword: String) {
        self.conversationId = conversationId
        self.messageId = messageId
        self.isData = category.hasSuffix("_DATA")
        self.userId = userId
        self.userFullname = fullname
        self.createdAt = createdAt
        let title = SearchResult.attributedText(text: fullname,
                                                textAttributes: SearchResult.titleAttributes,
                                                keyword: keyword,
                                                keywordAttributes: SearchResult.highlightedTitleAttributes)
        let badgeImage = SearchResult.userBadgeImage(isVerified: isVerified,
                                                     appId: appId)
        let superscript = createdAt.toUTCDate().timeAgo()
        let description: NSAttributedString?
        if isData {
            description = NSAttributedString(string: R.string.localizable.notification_content_file(),
                                             attributes: SearchResult.normalDescriptionAttributes)
        } else {
            // TODO: Tokenize
            description = SearchResult.attributedText(text: content,
                                                      textAttributes: SearchResult.largerDescriptionAttributes,
                                                      keyword: keyword,
                                                      keywordAttributes: SearchResult.highlightedLargerDescriptionAttributes)
        }
        super.init(iconUrl: avatarUrl,
                   title: title,
                   badgeImage: badgeImage,
                   superscript: superscript,
                   description: description)
    }
    
}
