import Foundation

class SearchResult {
    
    let iconUrl: String
    let title: NSAttributedString?
    let badgeImage: UIImage?
    let superscript: String?
    let description: NSAttributedString?
    
    init(iconUrl: String, title: NSAttributedString?, badgeImage: UIImage?, superscript: String?, description: NSAttributedString?) {
        self.iconUrl = iconUrl
        self.title = title
        self.badgeImage = badgeImage
        self.superscript = superscript
        self.description = description
    }
    
}

extension SearchResult {
    
    typealias Attributes = [NSAttributedString.Key: Any]
    
    static let titleFont = UIFont.systemFont(ofSize: 16)
    static let titleAttributes: Attributes = [
        .font: titleFont,
        .foregroundColor: UIColor.darkText
    ]
    static let highlightedTitleAttributes: Attributes = [
        .font: titleFont,
        .foregroundColor: UIColor.highlightedText
    ]
    
    static let normalDescriptionFont = UIFont.systemFont(ofSize: 12)
    static let normalDescriptionAttributes: Attributes = [
        .font: normalDescriptionFont,
        .foregroundColor: UIColor.descriptionText
    ]
    static let highlightedNormalDescriptionAttributes: Attributes = [
        .font: normalDescriptionFont,
        .foregroundColor: UIColor.highlightedText
    ]
    
    static let largerDescriptionFont = UIFont.systemFont(ofSize: 14)
    static let largerDescriptionAttributes: Attributes = [
        .font: largerDescriptionFont,
        .foregroundColor: UIColor.descriptionText
    ]
    static let highlightedLargerDescriptionAttributes: Attributes = [
        .font: largerDescriptionFont,
        .foregroundColor: UIColor.highlightedText
    ]
    
    static func attributedText(text: String, textAttributes: Attributes, keyword: String, keywordAttributes: Attributes) -> NSAttributedString {
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
    
    static func userBadgeImage(isVerified: Bool, appId: String?) -> UIImage? {
        if isVerified {
            return R.image.ic_user_verified()
        } else if !appId.isNilOrEmpty {
            return R.image.ic_user_bot()
        } else {
            return nil
        }
    }
    
    static func description(user: UserItem, keyword: String) -> NSAttributedString? {
        if user.identityNumber.contains(keyword) {
            let text = R.string.localizable.search_result_prefix_id() + user.identityNumber
            return SearchResult.attributedText(text: text,
                                               textAttributes: SearchResult.normalDescriptionAttributes,
                                               keyword: keyword,
                                               keywordAttributes: SearchResult.highlightedNormalDescriptionAttributes)
        } else if let phone = user.phone, phone.contains(keyword) {
            let text = R.string.localizable.search_result_prefix_phone() + phone
            return SearchResult.attributedText(text: text,
                                               textAttributes: SearchResult.normalDescriptionAttributes,
                                               keyword: keyword,
                                               keywordAttributes: SearchResult.highlightedNormalDescriptionAttributes)
        } else {
            return nil
        }
    }
    
}
