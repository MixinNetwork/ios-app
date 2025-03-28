import Foundation
import MixinServices

class SearchResult {
    
    let iconUrl: String
    let badgeImage: UIImage?
    let superscript: String?
    
    var title: NSAttributedString?
    var description: NSAttributedString?
    
    init(iconUrl: String, badgeImage: UIImage?, superscript: String?) {
        self.iconUrl = iconUrl
        self.badgeImage = badgeImage
        self.superscript = superscript
        updateTitleAndDescription()
    }
    
    func updateTitleAndDescription() {
        
    }
    
}

extension SearchResult {
    
    typealias Attributes = [NSAttributedString.Key: Any]
    
    static var titleAttributes: Attributes {
        return [.font: UIFont.preferredFont(forTextStyle: .callout),
                .foregroundColor: UIColor.text]
    }
    static var highlightedTitleAttributes: Attributes {
        return [.font: UIFont.preferredFont(forTextStyle: .callout),
                .foregroundColor: UIColor.highlightedText]
    }
    
    static var normalDescriptionAttributes: Attributes {
        return [.font: UIFont.preferredFont(forTextStyle: .caption1),
                .foregroundColor: R.color.text_tertiary()!]
    }
    static var highlightedNormalDescriptionAttributes: Attributes {
        return [.font: UIFont.preferredFont(forTextStyle: .caption1),
                .foregroundColor: UIColor.highlightedText]
    }
    
    static var largerDescriptionAttributes: Attributes {
        return [.font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14)),
                .foregroundColor: R.color.text_tertiary()!]
    }
    static var highlightedLargerDescriptionAttributes: Attributes {
        return [.font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14)),
                .foregroundColor: UIColor.highlightedText]
    }
    
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
    
    static func description(identityNumber: String?, phoneNumber: String?, keyword: String) -> NSAttributedString? {
        if let identityNumber = identityNumber, identityNumber.contains(keyword) {
            SearchResult.attributedText(
                text: R.string.localizable.contact_mixin_id(identityNumber),
                textAttributes: SearchResult.normalDescriptionAttributes,
                keyword: keyword,
                keywordAttributes: SearchResult.highlightedNormalDescriptionAttributes
            )
        } else if let phoneNumber = phoneNumber, phoneNumber.contains(keyword) {
            SearchResult.attributedText(
                text: R.string.localizable.search_result_prefix_phone() + phoneNumber,
                textAttributes: SearchResult.normalDescriptionAttributes,
                keyword: keyword,
                keywordAttributes: SearchResult.highlightedNormalDescriptionAttributes
            )
        } else if let identityNumber = identityNumber {
            NSAttributedString(
                string: identityNumber,
                attributes: SearchResult.normalDescriptionAttributes
            )
        } else {
            nil
        }
    }
    
    static func description(user: UserItem, keyword: String) -> NSAttributedString? {
        description(identityNumber: user.identityNumber, phoneNumber: user.phone, keyword: keyword)
    }
    
}
