import UIKit
import MixinServices

class PresentationFontSize {
    
    private(set) var scaled: UIFont
    
    private let rawFont: UIFont
    
    init(font: UIFont) {
        rawFont = font
        scaled = Self.scaledFont(for: font)
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
        scaled = Self.scaledFont(for: rawFont)
    }
    
    class func scaledFont(for font: UIFont) -> UIFont {
        UIFontMetrics.default.scaledFont(for: font)
    }
    
}
