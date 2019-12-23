import UIKit
import MixinServices

class MessageViewModel: CustomDebugStringConvertible {
    
    static let bottomSeparatorHeight: CGFloat = 10
    
    let message: MessageItem
    let quote: Quote?
    let time: String
    
    private(set) var layoutWidth: CGFloat = 414
    
    var thumbnail: UIImage?
    var backgroundImage: UIImage?
    var backgroundImageFrame = CGRect.zero
    var cellHeight: CGFloat = 44
    
    var contentMargin: Margin {
        return Margin(leading: 16, trailing: 10, top: 7, bottom: 7)
    }
    
    var debugDescription: String {
        return "MessageViewModel for message: \(message), layoutWidth: \(layoutWidth), cellHeight: \(cellHeight)"
    }
    
    var style: Style {
        get {
            return _style
        }
        set {
            layout(width: layoutWidth, style: newValue)
        }
    }
    
    var bottomSeparatorHeight: CGFloat {
        if style.contains(.bottomSeparator) {
            return MessageViewModel.bottomSeparatorHeight
        } else {
            return 0
        }
    }
    
    private var _style: Style = []
    
    init(message: MessageItem) {
        self.message = message
        self.time = message.createdAt.toUTCDate().timeHoursAndMinutes()
        if let thumbImage = message.thumbImage, let imageData = Data(base64Encoded: thumbImage)  {
            thumbnail = UIImage(data: imageData)
        } else {
            thumbnail = nil
        }
        if let quoteContent = message.quoteContent {
            self.quote = Quote(quoteContent: quoteContent)
        } else {
            self.quote = nil
        }
    }
    
    func layout(width: CGFloat, style: Style) {
        layoutWidth = width
        _style = style
    }
    
}

extension MessageViewModel {
    
    struct Style: OptionSet {
        let rawValue: Int
        static let received = Style(rawValue: 1 << 0)
        static let tail = Style(rawValue: 1 << 1)
        static let bottomSeparator = Style(rawValue: 1 << 2)
        static let fullname = Style(rawValue: 1 << 3)
    }
    
    struct Margin {
        let leading: CGFloat
        let trailing: CGFloat
        let top: CGFloat
        let bottom: CGFloat
        let horizontal: CGFloat
        let vertical: CGFloat
        
        init(leading: CGFloat, trailing: CGFloat, top: CGFloat, bottom: CGFloat) {
            self.leading = leading
            self.trailing = trailing
            self.top = top
            self.bottom = bottom
            self.horizontal = leading + trailing
            self.vertical = top + bottom
        }
    }
    
    enum ImageSet {
        
        enum MessageStatus {
            static let size = CGSize(width: doubleCheckmark.size.width,
                                     height: pending.size.height)
            static let pending = R.image.ic_chat_time()!.withRenderingMode(.alwaysTemplate)
            static let checkmark = R.image.ic_chat_checkmark()!.withRenderingMode(.alwaysTemplate)
            static let doubleCheckmark = R.image.ic_chat_double_checkmark()!.withRenderingMode(.alwaysTemplate)
        }
        
    }
    
}
