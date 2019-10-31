import UIKit

class CoreTextFontSet {
    
    static let textMessage = CoreTextFontSet(size: 16)
    static let recalledMessage = CoreTextFontSet(size: 16, matrix: .italic)
    
    enum FontDescription {
        case textStyle(UIFont.TextStyle)
        case size(CGFloat, CGAffineTransform?)
    }
    
    private(set) var ctFont: CTFont
    private(set) var lineHeight: CGFloat
    
    private let fontDescription: FontDescription
    
    init(style: UIFont.TextStyle) {
        fontDescription = .textStyle(style)
        (ctFont, lineHeight) = CoreTextFontSet.ctFontAndLineHeight(for: fontDescription)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(contentSizeCategoryDidChange(_:)),
                                               name: UIContentSizeCategory.didChangeNotification,
                                               object: nil)
    }
    
    init(size: CGFloat, matrix: CGAffineTransform? = nil) {
        fontDescription = .size(size, matrix)
        (ctFont, lineHeight) = CoreTextFontSet.ctFontAndLineHeight(for: fontDescription)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(contentSizeCategoryDidChange(_:)),
                                               name: UIContentSizeCategory.didChangeNotification,
                                               object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func contentSizeCategoryDidChange(_ notification: Notification) {
        (ctFont, lineHeight) = CoreTextFontSet.ctFontAndLineHeight(for: fontDescription)
    }
    
    private static func ctFontAndLineHeight(for description: FontDescription) -> (CTFont, CGFloat) {
        let font: UIFont
        switch description {
        case let .textStyle(style):
            font = .preferredFont(forTextStyle: style)
        case let .size(size, matrix):
            if let matrix = matrix {
                let descriptor = UIFont.systemFont(ofSize: size).fontDescriptor.withMatrix(matrix)
                let normalFont = UIFont(descriptor: descriptor, size: size)
                font = UIFontMetrics.default.scaledFont(for: normalFont)
            } else {
                font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: size))
            }
        }
        let desc = font.fontDescriptor as CTFontDescriptor
        let ctFont = CTFontCreateWithFontDescriptor(desc, 0, nil)
        let lineHeight = round(font.lineHeight)
        return (ctFont, lineHeight)
    }
    
}
