import Foundation

struct SearchResult {
    
    let target: Target
    let style: Style
    let name: String
    let iconUrl: String?
    let title: NSAttributedString?
    let badgeImage: UIImage?
    let superscript: String?
    let description: NSAttributedString?
    
    init(user: UserItem, keyword: String) {
        self.target = .contact(user)
        self.style = .normal
        self.name = user.fullName
        self.iconUrl = user.avatarUrl
        self.title = SearchResult.attributedText(text: user.fullName,
                                                 textAttributes: SearchResult.titleAttributes,
                                                 keyword: keyword,
                                                 keywordAttributes: SearchResult.highlightedTitleAttributes)
        if user.isVerified {
            self.badgeImage = R.image.ic_user_verified()
        } else if user.appId != nil {
            self.badgeImage = R.image.ic_user_bot()
        } else {
            self.badgeImage = nil
        }
        self.superscript = nil
        if user.identityNumber.contains(keyword) {
            self.description = SearchResult.attributedText(text: user.identityNumber,
                                                           textAttributes: SearchResult.normalDescriptionAttributes,
                                                           keyword: keyword,
                                                           keywordAttributes: SearchResult.highlightedNormalDescriptionAttributes)
        } else if let phone = user.phone, phone.contains(keyword) {
            self.description = SearchResult.attributedText(text: phone,
                                                           textAttributes: SearchResult.normalDescriptionAttributes,
                                                           keyword: keyword,
                                                           keywordAttributes: SearchResult.highlightedNormalDescriptionAttributes)
        } else {
            self.description = nil
        }
    }
    
    init(group: ConversationItem, keyword: String) {
        self.target = .group(group)
        self.style = .normal
        self.name = group.name
        self.iconUrl = group.iconUrl
        self.title = SearchResult.attributedText(text: group.name,
                                                 textAttributes: SearchResult.titleAttributes,
                                                 keyword: keyword,
                                                 keywordAttributes: SearchResult.highlightedTitleAttributes)
        self.badgeImage = nil
        self.superscript = nil
        self.description = nil
    }
    
    init(conversationId: String, category: ConversationCategory, name: String, iconUrl: String, userId: String?, relatedMessageCount: Int, keyword: String) {
        switch category {
        case .CONTACT:
            self.target = .searchMessageWithContact(userId: userId ?? "", conversationId: conversationId)
        case .GROUP:
            self.target = .searchMessageWithGroup(conversationId: conversationId)
        }
        self.style = .normal
        self.name = name
        self.iconUrl = iconUrl
        self.title = SearchResult.attributedText(text: name,
                                                 textAttributes: SearchResult.titleAttributes,
                                                 keyword: keyword,
                                                 keywordAttributes: SearchResult.highlightedTitleAttributes)
        self.badgeImage = nil
        self.superscript = nil
        let desc = "\(relatedMessageCount)" + R.string.localizable.search_related_messages_count()
        self.description = NSAttributedString(string: desc, attributes: SearchResult.normalDescriptionAttributes)
    }
    
}

extension SearchResult {
    
    enum Target {
        case contact(UserItem)
        case group(ConversationItem)
        case searchMessageWithContact(userId: String, conversationId: String)
        case searchMessageWithGroup(conversationId: String)
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
