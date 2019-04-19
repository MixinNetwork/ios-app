import Foundation

struct ConversationSearchResult {
    
    let category: Category
    let target: Target
    let style: Style
    let iconUrl: String?
    let userId: String?
    let title: NSAttributedString?
    let badgeImage: UIImage?
    let superscript: String?
    let description: NSAttributedString?
    
    init(user: User, keyword: String) {
        self.category = .contact(id: user.userId)
        self.target = .user(id: user.userId)
        self.style = .normal
        self.iconUrl = user.avatarUrl
        self.userId = user.userId
        if let fullName = user.fullName {
            self.title = ConversationSearchResult.attributedText(text: fullName,
                                                                 textAttributes: ConversationSearchResult.titleAttributes,
                                                                 keyword: keyword,
                                                                 keywordAttributes: ConversationSearchResult.highlightedTitleAttributes)
        } else {
            self.title = nil
        }
        if user.isVerified ?? false {
            self.badgeImage = R.image.ic_user_verified()
        } else if user.appId != nil {
            self.badgeImage = R.image.ic_user_bot()
        } else {
            self.badgeImage = nil
        }
        self.superscript = nil
        if user.identityNumber.contains(keyword) {
            self.description = ConversationSearchResult.attributedText(text: user.identityNumber,
                                                                       textAttributes: ConversationSearchResult.normalDescriptionAttributes,
                                                                       keyword: keyword,
                                                                       keywordAttributes: ConversationSearchResult.highlightedNormalDescriptionAttributes)
        } else if let phone = user.phone, phone.contains(keyword) {
            self.description = ConversationSearchResult.attributedText(text: phone,
                                                                       textAttributes: ConversationSearchResult.normalDescriptionAttributes,
                                                                       keyword: keyword,
                                                                       keywordAttributes: ConversationSearchResult.highlightedNormalDescriptionAttributes)
        } else {
            self.description = nil
        }
    }
    
    init(group: Conversation, keyword: String) {
        self.category = .group
        self.target = .conversation(id: group.conversationId)
        self.style = .normal
        self.iconUrl = group.iconUrl
        self.userId = nil
        if let name = group.name {
            self.title = ConversationSearchResult.attributedText(text: name,
                                                                 textAttributes: ConversationSearchResult.titleAttributes,
                                                                 keyword: keyword,
                                                                 keywordAttributes: ConversationSearchResult.highlightedTitleAttributes)
        } else {
            self.title = nil
        }
        self.badgeImage = nil
        self.superscript = nil
        self.description = nil
    }
    
    init(conversationId: String, category: ConversationCategory, name: String, iconUrl: String, userId: String?, relatedMessageCount: Int, keyword: String) {
        switch category {
        case .CONTACT:
            self.category = .contact(id: userId ?? "")
        case .GROUP:
            self.category = .group
        }
        self.target = .searchMessages(conversationId: conversationId)
        self.style = .normal
        self.iconUrl = iconUrl
        self.userId = userId
        self.title = ConversationSearchResult.attributedText(text: name,
                                                             textAttributes: ConversationSearchResult.titleAttributes,
                                                             keyword: keyword,
                                                             keywordAttributes: ConversationSearchResult.highlightedTitleAttributes)
        self.badgeImage = nil
        self.superscript = nil
        let desc = "\(relatedMessageCount)" + R.string.localizable.search_related_messages_count()
        self.description = NSAttributedString(string: desc, attributes: ConversationSearchResult.normalDescriptionAttributes)
    }
    
}

extension ConversationSearchResult {
    
    enum Category {
        case contact(id: String)
        case group
    }
    
    enum Target {
        case user(id: String)
        case conversation(id: String)
        case searchMessages(conversationId: String)
    }
    
    enum Style {
        case normal
        case largerDescription
    }
    
    private typealias Attributes = [NSAttributedString.Key: Any]
    
    private static let titleFont = UIFont.systemFont(ofSize: 16)
    private static let titleAttributes: Attributes = [
        .font: titleFont,
        .foregroundColor: UIColor.darkText
    ]
    private static let highlightedTitleAttributes: Attributes = [
        .font: titleFont,
        .foregroundColor: UIColor.highlightedText
    ]
    
    private static let normalDescriptionFont = UIFont.systemFont(ofSize: 12)
    private static let normalDescriptionAttributes: Attributes = [
        .font: normalDescriptionFont,
        .foregroundColor: UIColor.descriptionText
    ]
    private static let highlightedNormalDescriptionAttributes: Attributes = [
        .font: normalDescriptionFont,
        .foregroundColor: UIColor.highlightedText
    ]
    
    private static func attributedText(text: String, textAttributes: Attributes, keyword: String, keywordAttributes: Attributes) -> NSAttributedString {
        let str = NSMutableAttributedString(string: text, attributes: textAttributes)
        let nsText = NSString(string: text)
        let options: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
        let invalidRange = NSRange(location: NSNotFound, length: 0)
        var enclosingRange = NSRange(location: 0, length: nsText.length)
        while !NSEqualRanges(enclosingRange, invalidRange) {
            let range = nsText.range(of: keyword, options: options, range: enclosingRange)
            guard !NSEqualRanges(range, invalidRange) else {
                break
            }
            str.setAttributes(keywordAttributes, range: range)
            let nextLocation = NSMaxRange(range)
            enclosingRange = NSRange(location: nextLocation, length: nsText.length - nextLocation)
        }
        return str
    }
    
}
