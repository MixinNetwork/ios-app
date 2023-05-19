import UIKit
import MixinServices
import SDWebImage

class MessageViewModel: CustomDebugStringConvertible {
    
    static let bottomSeparatorHeight: CGFloat = 10
    
    class var quotedMessageMargin: Margin {
        Margin(leading: 9, trailing: 2, top: 1, bottom: 4)
    }
    
    class var supportsQuoting: Bool {
        false
    }
    
    let message: MessageItem
    let isEncrypted: Bool
    let isPinned: Bool
    let time: String
    let isStackedPhoto: Bool
    let quotedMessageViewModel: QuotedMessageViewModel?
    
    private(set) var layoutWidth: CGFloat = 414
    
    var thumbnail: UIImage?
    var backgroundImage: UIImage?
    var backgroundImageFrame = CGRect.zero
    var quotedMessageViewFrame: CGRect = .zero
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
    
    var trailingInfoColor: UIColor {
        .accessoryText
    }
    
    private var _style: Style = []
    
    init(message: MessageItem) {
        self.message = message
        self.isEncrypted = message.category.hasPrefix("SIGNAL_") || message.category.hasPrefix("ENCRYPTED_")
        self.isPinned = message.isPinned ?? false
        self.time = message.createdAt.toUTCDate().timeHoursAndMinutes()
        self.isStackedPhoto = message.category == MessageCategory.STACKED_PHOTO.rawValue
        thumbnail = UIImage(thumbnailString: message.thumbImage)
        
        var quoteIfExist: Quote? = nil
        if Self.supportsQuoting, let id = message.quoteMessageId, !id.isEmpty {
            if let quoteContent = message.quoteContent {
                if let message = try? JSONDecoder.default.decode(MessageItem.self, from: quoteContent) {
                    quoteIfExist = Quote(quotedMessage: message)
                }
            } else {
                quoteIfExist = .notFound
            }
        }
        if let quote = quoteIfExist {
            quotedMessageViewModel = QuotedMessageViewModel(quote: quote)
        } else {
            quotedMessageViewModel = nil
        }
    }
    
    func layout(width: CGFloat, style: Style) {
        layoutWidth = width
        _style = style
        if let quotedMessageViewModel = quotedMessageViewModel {
            let quoteViewLayoutWidth = self.quoteViewLayoutWidth(from: width)
            quotedMessageViewModel.ensureContentSize(width: quoteViewLayoutWidth)
        }
    }
    
    func quoteViewLayoutWidth(from width: CGFloat) -> CGFloat {
        width
    }
    
    func layoutQuotedMessageIfPresent() {
        guard let viewModel = quotedMessageViewModel else {
            return
        }
        let x: CGFloat
        if style.contains(.received) {
            x = backgroundImageFrame.origin.x + Self.quotedMessageMargin.leading
        } else {
            x = backgroundImageFrame.origin.x + Self.quotedMessageMargin.trailing
        }
        let width = backgroundImageFrame.width - Self.quotedMessageMargin.horizontal
        quotedMessageViewFrame = CGRect(x: x,
                                        y: backgroundImageFrame.origin.y + Self.quotedMessageMargin.top,
                                        width: width,
                                        height: viewModel.contentSize.height)
        viewModel.layout(width: width, style: style)
    }
    
    func updateKey(content: String, key: Data?, digest: Data?) {
        message.content = content
        message.mediaKey = key
        message.mediaDigest = digest
    }
    
}

extension MessageViewModel {
    
    struct Style: OptionSet {
        let rawValue: Int
        static let received = Style(rawValue: 1 << 0)
        static let tail = Style(rawValue: 1 << 1)
        static let bottomSeparator = Style(rawValue: 1 << 2)
        static let fullname = Style(rawValue: 1 << 3)
        static let forwardedByBot = Style(rawValue: 1 << 4)
        static let noStatus = Style(rawValue: 1 << 5)
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
    
    enum StatusImage {
        
        case pending
        case checkmark
        case doubleCheckmark
        
        static let size = CGSize(width: 12, height: 9)
        
        private static let pending2xImage = SDAnimatedImage(named: "ic_time_animation@2x.gif")!
        private static let pending3xImage = SDAnimatedImage(named: "ic_time_animation@3x.gif")!
        private static let pendingDark2xImage = SDAnimatedImage(named: "ic_time_animation_dark@2x.gif")!
        private static let pendingDark3xImage = SDAnimatedImage(named: "ic_time_animation_dark@3x.gif")!
        private static let checkmarkImage = R.image.ic_chat_checkmark()!.withRenderingMode(.alwaysTemplate)
        private static let doubleCheckmarkImage = R.image.ic_chat_double_checkmark()!.withRenderingMode(.alwaysTemplate)
        
        func image(traitCollection: UITraitCollection) -> UIImage {
            switch self {
            case .pending:
                let scale = UIScreen.main.scale
                if traitCollection.userInterfaceStyle == .light {
                    return scale == 2 ? StatusImage.pending2xImage : StatusImage.pending3xImage
                } else {
                    return scale == 2 ? StatusImage.pendingDark2xImage : StatusImage.pendingDark3xImage
                }
            case .checkmark:
                return StatusImage.checkmarkImage
            case .doubleCheckmark:
                return StatusImage.doubleCheckmarkImage
            }
        }
        
    }
    
}
