import UIKit
import MixinServices

class MessageFontSet: PresentationFontSize {
    
    static let time = MessageFontSet(size: 11, weight: .light)
    static let transcriptDigest = MessageFontSet(size: 12, weight: .regular)
    static let fullname = MessageFontSet(size: 14, weight: .regular)
    static let normalContent = MessageFontSet(size: 16, weight: .regular)
    static let systemMessage = MessageFontSet(size: 14, weight: .regular)
    static let appButtonTitle = MessageFontSet(size: 16, weight: .regular)
    static let quoteTitle = MessageFontSet(size: 15, weight: .regular)
    static let inputPlaceholder = MessageFontSet(size: 13, weight: .regular)
    static let normalQuoteSubtitle = MessageFontSet(size: 13, weight: .light)
    static let cardTitle = MessageFontSet(size: 17, weight: .regular)
    static let cardSubtitle = MessageFontSet(size: 14, weight: .regular)
    static let transferAmount = MessageFontSet(size: 20, weight: .regular)
    static let recalledQuoteSubtitle: MessageFontSet = {
        let descriptor = UIFont.systemFont(ofSize: 13, weight: .light).fontDescriptor.withMatrix(.italic)
        let font = UIFont(descriptor: descriptor, size: 13)
        return MessageFontSet(font: font)
    }()
    static let recalledContent: MessageFontSet = {
        let descriptor = UIFont.systemFont(ofSize: 16).fontDescriptor.withMatrix(.italic)
        let font = UIFont(descriptor: descriptor, size: 16)
        return MessageFontSet(font: font)
    }()
    
    private static let chatFontSizeScaledMap: [ChatFontSize: [CGFloat: CGFloat]] = [
        .extraSmall:        [11: 10, 12: 10, 13: 11, 14: 12, 15: 13, 16: 14, 17: 15, 20: 17],
        .small:             [11: 10, 12: 11, 13: 12, 14: 13, 15: 14, 16: 15, 17: 15, 20: 18],
        .medium:            [11: 11, 12: 11, 13: 12, 14: 13, 15: 14, 16: 15, 17: 16, 20: 19],
        .regular:           [11: 11, 12: 12, 13: 13, 14: 14, 15: 15, 16: 16, 17: 17, 20: 20],
        .large:             [11: 12, 12: 13, 13: 14, 14: 15, 15: 16, 16: 17, 17: 19, 20: 22],
        .extraLarge:        [11: 13, 12: 14, 13: 15, 14: 17, 15: 18, 16: 19, 17: 20, 20: 24],
        .extraExtraLarge:   [11: 15, 12: 16, 13: 17, 14: 18, 15: 20, 16: 21, 17: 22, 20: 26],
    ]
    
    override class func scaledFont(for font: UIFont) -> UIFont {
        if AppGroupUserDefaults.User.useSystemFont {
            return super.scaledFont(for: font)
        } else {
            let fontSize = AppGroupUserDefaults.User.chatFontSize
            if let fontSet = chatFontSizeScaledMap[fontSize], let scaledSize = fontSet[font.pointSize] {
                return font.withSize(scaledSize)
            } else {
                return super.scaledFont(for: font)
            }
        }
    }
    
}
