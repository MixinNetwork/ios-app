import UIKit
import MixinServices

class MessageSearchResult: SearchResult {
    
    enum SpecializedCategory {
        case data
        case transcript
    }
    
    let conversationId: String
    let messageId: String
    let specializedCategory: SpecializedCategory?
    let userId: String
    let userFullname: String
    let createdAt: String
    
    private let content: String
    private let keyword: String
    
    init(
        conversationId: String, messageId: String, category: String, content: String, createdAt: String,
        userId: String, fullname: String, avatarUrl: String, isVerified: Bool, appId: String?,
        membership: User.Membership?, keyword: String
    ) {
        self.conversationId = conversationId
        self.messageId = messageId
        if category.hasSuffix("_DATA") {
            self.specializedCategory = .data
        } else if category.hasSuffix("_TRANSCRIPT") {
            self.specializedCategory = .transcript
        } else {
            self.specializedCategory = nil
        }
        self.content = content
        self.userId = userId
        self.userFullname = fullname
        self.createdAt = createdAt
        self.keyword = keyword
        let badgeImage = UserBadgeIcon.image(
            membership: membership,
            isVerified: isVerified,
            appID: appId
        )
        let superscript = createdAt.toUTCDate().timeAgo()
        super.init(iconUrl: avatarUrl,
                   badgeImage: badgeImage,
                   superscript: superscript)
    }
    
    override func updateTitleAndDescription() {
        title = SearchResult.attributedText(text: userFullname,
                                            textAttributes: SearchResult.titleAttributes,
                                            keyword: keyword,
                                            keywordAttributes: SearchResult.highlightedTitleAttributes)
        
        if let category = specializedCategory {
            switch category {
            case .data:
                description = NSAttributedString(string: R.string.localizable.content_file(),
                                                 attributes: SearchResult.normalDescriptionAttributes)
            case .transcript:
                description = NSAttributedString(string: R.string.localizable.content_transcript(),
                                                 attributes: SearchResult.normalDescriptionAttributes)
            }
        } else {
            // TODO: Tokenize
            description = SearchResult.attributedText(text: content,
                                                      textAttributes: SearchResult.largerDescriptionAttributes,
                                                      keyword: keyword,
                                                      keywordAttributes: SearchResult.highlightedLargerDescriptionAttributes)
        }
    }
    
}
