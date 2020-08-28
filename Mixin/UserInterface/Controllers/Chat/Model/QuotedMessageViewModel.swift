import Foundation

class QuotedMessageViewModel {
    
    static let contentMargin = MessageViewModel.Margin(leading: 11, trailing: 11, top: 6, bottom: 6)
    static let titleRightMargin: CGFloat = 4
    static let iconSize = CGSize(width: 15, height: 15)
    static let iconTrailingMargin: CGFloat = 4
    static let subtitleTopMargin: CGFloat = 4
    static let subtitleRightMargin: CGFloat = 16
    static let subtitleNumberOfLines = 3
    static let imageSize = CGSize(width: 50, height: 50)
    static let avatarImageMargin: CGFloat = 8
    
    let quote: Quote
    
    private(set) var contentSize: CGSize = .zero
    private(set) var backgroundFrame: CGRect = .zero
    private(set) var titleFrame: CGRect = .zero
    private(set) var iconFrame: CGRect = .zero
    private(set) var subtitleFrame: CGRect = .zero
    private(set) var subtitleFont = MessageFontSet.normalQuoteSubtitle.scaled
    private(set) var imageFrame: CGRect = .zero
    
    private var paddedQuoteIconWidth: CGFloat = 0
    private var titleSize: CGSize = .zero
    private var subtitleSize: CGSize = .zero
    
    init(quote: Quote) {
        self.quote = quote
    }
    
    func ensureContentSize(width: CGFloat) {
        switch quote.category {
        case .normal:
            subtitleFont = MessageFontSet.normalQuoteSubtitle.scaled
        case .recalled:
            subtitleFont = MessageFontSet.recalledQuoteSubtitle.scaled
        }
        
        paddedQuoteIconWidth = quote.icon == nil ? 0 : Self.iconSize.width + Self.iconTrailingMargin
        let quoteImageWidth = quote.image == nil ? 0 : Self.imageSize.width
        let maxTitleWidth = width - quoteImageWidth
        let maxSubtitleWidth = width - paddedQuoteIconWidth - quoteImageWidth - Self.subtitleRightMargin
        
        if quote == .notFound {
            titleSize = .zero
        } else {
            let titleHeight = MessageFontSet.quoteTitle.scaled.lineHeight
            var titleWidth = (quote.title as NSString)
                .size(withAttributes: [.font: MessageFontSet.quoteTitle.scaled])
                .width
            titleWidth = ceil(titleWidth)
            titleWidth = min(maxTitleWidth, titleWidth)
            titleSize = ceil(CGSize(width: titleWidth, height: titleHeight))
        }
        
        let subtitleFittingSize = CGSize(width: maxSubtitleWidth, height: UIView.layoutFittingExpandedSize.height)
        subtitleSize = (quote.subtitle as NSString)
            .boundingRect(with: subtitleFittingSize,
                          options: [.usesLineFragmentOrigin, .usesFontLeading],
                          attributes: [.font: subtitleFont],
                          context: nil)
            .size
        var subtitleHeight = subtitleSize.height
        subtitleHeight = min(subtitleFont.lineHeight * CGFloat(Self.subtitleNumberOfLines), subtitleHeight)
        subtitleHeight = max(ceil(subtitleFont.lineHeight), subtitleHeight)
        subtitleSize = ceil(CGSize(width: subtitleSize.width, height: subtitleHeight))
        
        var contentWidth = max(titleSize.width + quoteImageWidth,
                               paddedQuoteIconWidth + subtitleSize.width + quoteImageWidth)
        contentWidth += Self.contentMargin.horizontal
        
        var titlesHeight = Self.contentMargin.vertical + subtitleSize.height
        if titleSize.height > 0 {
            titlesHeight += (Self.subtitleTopMargin + titleSize.height)
        }
        
        var contentHeight = titlesHeight
        if quote.image != nil {
            contentHeight = max(contentHeight, Self.imageSize.height)
        }
        contentSize = CGSize(width: contentWidth, height: contentHeight)
    }
    
    func layout(width: CGFloat, style: MessageViewModel.Style) {
        let backgroundSize = CGSize(width: width, height: contentSize.height)
        backgroundFrame = CGRect(origin: .zero, size: backgroundSize)
        let titleOrigin = CGPoint(x: backgroundFrame.origin.x + Self.contentMargin.leading,
                                  y: backgroundFrame.origin.y + Self.contentMargin.top)
        titleFrame = CGRect(origin: titleOrigin, size: titleSize)
        
        var iconOrigin = CGPoint(x: titleFrame.origin.x,
                                 y: round(titleFrame.maxY + (subtitleFont.lineHeight - Self.iconSize.height) / 2))
        if titleSize.height > 0 {
            iconOrigin.y += Self.subtitleTopMargin
        }
        if quote.icon == nil {
            iconFrame = CGRect(origin: iconOrigin, size: .zero)
        } else {
            iconFrame = CGRect(origin: iconOrigin, size: Self.iconSize)
        }
        
        subtitleFrame = CGRect(x: titleFrame.origin.x + paddedQuoteIconWidth,
                               y: titleFrame.maxY,
                               width: subtitleSize.width,
                               height: subtitleSize.height)
        if titleSize.height > 0 {
            subtitleFrame.origin.y += Self.subtitleTopMargin
        }
        
        if let image = quote.image {
            let imageOrigin = CGPoint(x: backgroundFrame.maxX - Self.imageSize.width,
                                      y: backgroundFrame.origin.y)
            let imageSize = quote.image == nil ? .zero : Self.imageSize
            if case .user = image {
                imageFrame = CGRect(origin: imageOrigin, size: imageSize)
                    .insetBy(dx: Self.avatarImageMargin, dy: Self.avatarImageMargin)
            } else {
                imageFrame = CGRect(origin: imageOrigin, size: imageSize)
            }
            let intersection = titleFrame.maxX - imageFrame.minX
            if intersection > -Self.titleRightMargin {
                titleFrame.size.width -= Self.titleRightMargin + intersection
            }
        } else {
            imageFrame = .zero
        }
    }
    
}
