import UIKit
import MixinServices

class QuoteTextMessageViewModel: TextMessageViewModel {
    
    enum Quote {
        static let backgroundMargin = Margin(leading: 9, trailing: 2, top: 1, bottom: 4)
        static let contentMargin = Margin(leading: 11, trailing: 11, top: 6, bottom: 6)
        static let iconSize = CGSize(width: 15, height: 15)
        static let iconTrailingMargin: CGFloat = 4
        static let subtitleTopMargin: CGFloat = 4
        static let subtitleNumberOfLines = 3
        static let imageSize = CGSize(width: 50, height: 50)
        static let imageCornerRadius: CGFloat = 6
        static let avatarImageMargin: CGFloat = 8
    }
    
    override class var bubbleImageSet: BubbleImageSet.Type {
        return LightRightBubbleImageSet.self
    }
    
    private(set) var quoteBackgroundFrame = CGRect.zero
    private(set) var quoteTitleFrame = CGRect.zero
    private(set) var quoteIconFrame = CGRect.zero
    private(set) var quoteSubtitleFrame = CGRect.zero
    private(set) var quoteImageFrame = CGRect.zero
    private(set) var subtitleFont = MessageFontSet.normalQuoteSubtitle.scaled
    
    private var quoteMaxWidth: CGFloat = 0
    private var quoteContentHeight: CGFloat = 0
    
    override var contentLabelTopMargin: CGFloat {
        return fullnameHeight + quoteContentHeight + Quote.backgroundMargin.vertical
    }
    
    override var backgroundWidth: CGFloat {
        return max(super.backgroundWidth, quoteMaxWidth)
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        guard let quote = quote else {
            super.layout(width: width, style: style)
            return
        }
        switch quote.category {
        case .normal:
            subtitleFont = MessageFontSet.normalQuoteSubtitle.scaled
        case .recalled:
            subtitleFont = MessageFontSet.recalledQuoteSubtitle.scaled
        }
        let paddedQuoteIconWidth = quote.icon == nil ? 0 : Quote.iconSize.width + Quote.iconTrailingMargin
        let quoteImageWidth = quote.image == nil ? 0 : Quote.imageSize.width
        let maxTitleWidth = width
            - DetailInfoMessageViewModel.bubbleMargin.horizontal
            - Quote.backgroundMargin.horizontal
            - Quote.contentMargin.horizontal
            - quoteImageWidth
        let maxSubtitleWidth = width
            - DetailInfoMessageViewModel.bubbleMargin.horizontal
            - Quote.backgroundMargin.horizontal
            - Quote.contentMargin.horizontal
            - paddedQuoteIconWidth
            - quoteImageWidth
        
        let titleHeight = MessageFontSet.quoteTitle.scaled.lineHeight
        var titleWidth = (quote.title as NSString)
            .size(withAttributes: [.font: MessageFontSet.quoteTitle.scaled])
            .width
        titleWidth = ceil(titleWidth)
        titleWidth = min(maxTitleWidth, titleWidth)
        
        var subtitleSize = CGSize.zero
        let subtitleFittingSize = CGSize(width: maxSubtitleWidth, height: UIView.layoutFittingExpandedSize.height)
        subtitleSize = (quote.subtitle as NSString)
            .boundingRect(with: subtitleFittingSize, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: subtitleFont], context: nil)
            .size
        var subtitleHeight = subtitleSize.height
        subtitleHeight = min(subtitleFont.lineHeight * CGFloat(Quote.subtitleNumberOfLines), subtitleHeight)
        subtitleHeight = max(ceil(subtitleFont.lineHeight), subtitleHeight)
        subtitleSize = ceil(CGSize(width: subtitleSize.width, height: subtitleHeight))
        
        quoteMaxWidth = max(titleWidth + quoteImageWidth, paddedQuoteIconWidth + subtitleSize.width + quoteImageWidth)
            + Quote.contentMargin.horizontal
            + Quote.backgroundMargin.horizontal
        
        quoteContentHeight = max(Quote.imageSize.height, Quote.contentMargin.vertical + titleHeight + Quote.subtitleTopMargin + subtitleHeight)
        
        super.layout(width: width, style: style)
        
        if style.contains(.fullname) {
            backgroundImageFrame.origin.y += fullnameHeight
            backgroundImageFrame.size.height -= fullnameHeight
        }
        
        let quoteBackgroundOriginX: CGFloat
        if style.contains(.received) {
            quoteBackgroundOriginX = backgroundImageFrame.origin.x + Quote.backgroundMargin.leading
        } else {
            quoteBackgroundOriginX = backgroundImageFrame.origin.x + Quote.backgroundMargin.trailing
        }
        quoteBackgroundFrame = CGRect(x: quoteBackgroundOriginX,
                                      y: backgroundImageFrame.origin.y + Quote.backgroundMargin.top,
                                      width: backgroundImageFrame.width - Quote.backgroundMargin.horizontal,
                                      height: quoteContentHeight)
        quoteTitleFrame = CGRect(x: quoteBackgroundFrame.origin.x + Quote.contentMargin.leading,
                                 y: quoteBackgroundFrame.origin.y + Quote.contentMargin.top,
                                 width: titleWidth,
                                 height: titleHeight)
        
        let quoteIconOrigin = CGPoint(x: quoteTitleFrame.origin.x,
                                      y: round(quoteTitleFrame.maxY + Quote.subtitleTopMargin + (subtitleFont.lineHeight - Quote.iconSize.height) / 2))
        if quote.icon == nil {
            quoteIconFrame = CGRect(origin: quoteIconOrigin, size: .zero)
        } else {
            quoteIconFrame = CGRect(origin: quoteIconOrigin, size: Quote.iconSize)
        }
        
        quoteSubtitleFrame = CGRect(x: quoteTitleFrame.origin.x + paddedQuoteIconWidth,
                                    y: quoteTitleFrame.maxY + Quote.subtitleTopMargin,
                                    width: subtitleSize.width,
                                    height: subtitleSize.height)
        
        if let image = quote.image {
            let quoteImageOrigin = CGPoint(x: quoteBackgroundFrame.maxX - Quote.imageSize.width,
                                           y: quoteBackgroundFrame.origin.y)
            let quoteImageSize = quote.image == nil ? .zero : Quote.imageSize
            if case .user(_, _, _) = image {
                quoteImageFrame = CGRect(origin: quoteImageOrigin, size: quoteImageSize)
                    .insetBy(dx: Quote.avatarImageMargin, dy: Quote.avatarImageMargin)
            } else {
                quoteImageFrame = CGRect(origin: quoteImageOrigin, size: quoteImageSize)
            }
        } else {
            quoteImageFrame = .zero
        }
    }
    
}
