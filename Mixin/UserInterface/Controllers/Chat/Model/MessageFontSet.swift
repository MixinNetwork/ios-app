import UIKit

class MessageFontSet {
    
    static let time = MessageFontSet(size: 11, weight: .light)
    static let fullname = MessageFontSet(size: 14, weight: .regular)
    static let systemMessage = MessageFontSet(size: 14, weight: .regular)
    static let appButtonTitle = MessageFontSet(size: 16, weight: .regular)
    static let quoteTitle = MessageFontSet(style: .subheadline)
    static let normalQuoteSubtitle = MessageFontSet(size: 13, weight: .light)
    static let recalledQuoteSubtitle: MessageFontSet = {
        let descriptor = UIFont.systemFont(ofSize: 13, weight: .light)
            .fontDescriptor
            .withMatrix(.italic)
        let font = UIFont(descriptor: descriptor, size: 13)
        return MessageFontSet(font: font)
    }()
    static let normalConversationContent = MessageFontSet(size: 14, weight: .regular)
    static let recalledConversationContent: MessageFontSet = {
        let descriptor = UIFont.systemFont(ofSize: 14)
            .fontDescriptor
            .withMatrix(.italic)
        let font = UIFont(descriptor: descriptor, size: 14)
        return MessageFontSet(font: font)
    }()
    static let transcriptDigest = MessageFontSet(style: .caption1)
    
    enum FontDescription {
        case font(UIFont)
        case style(UIFont.TextStyle)
    }
    
    private(set) var scaled: UIFont
    
    private let fontDescription: FontDescription
    
    init(font: UIFont) {
        fontDescription = .font(font)
        self.scaled = MessageFontSet.font(for: fontDescription)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(contentSizeCategoryDidChange(_:)),
                                               name: UIContentSizeCategory.didChangeNotification,
                                               object: nil)
    }
    
    init(style: UIFont.TextStyle) {
        fontDescription = .style(style)
        scaled = MessageFontSet.font(for: fontDescription)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(contentSizeCategoryDidChange(_:)),
                                               name: UIContentSizeCategory.didChangeNotification,
                                               object: nil)
    }
    
    convenience init(size: CGFloat, weight: UIFont.Weight) {
        self.init(font: .systemFont(ofSize: size, weight: weight))
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func contentSizeCategoryDidChange(_ notification: Notification) {
        scaled = MessageFontSet.font(for: fontDescription)
    }
    
    private static func font(for description: FontDescription) -> UIFont {
        switch description {
        case .font(let font):
            return UIFontMetrics.default.scaledFont(for: font)
        case .style(let style):
            return UIFont.preferredFont(forTextStyle: style)
        }
    }
    
}
