import UIKit

class QuoteTextMessageViewModel: TextMessageViewModel {
    
    enum Quote {
        static let height = #imageLiteral(resourceName: "bg_chat_quote").size.height
        static let backgroundMargin = Margin(leading: 9, trailing: 3, top: 2, bottom: 0)
        static let contentMargin = Margin(leading: 11, trailing: 11, top: 5, bottom: 5)
        static let titleFont = UIFont.systemFont(ofSize: 16)
        static let titleHeight = ceil(titleFont.lineHeight)
        static let linesVerticalSpacing: CGFloat = 4
        static let iconSize = MessageCategory.maxIconSize
        static let iconTrailingMargin: CGFloat = 4
        static let subtitleFont = UIFont.systemFont(ofSize: 14, weight: UIFont.Weight.light)
        static let subtitleHeight = ceil(subtitleFont.lineHeight)
        static let imageSize = CGSize(width: height, height: height)
    }
    
    private(set) var quoteBackgroundFrame = CGRect.zero
    private(set) var quoteTitleFrame = CGRect.zero
    private(set) var quoteIconFrame = CGRect.zero
    private(set) var quoteSubtitleFrame = CGRect.zero
    private(set) var quoteImageFrame = CGRect.zero
    
    private var quoteMaxWidth: CGFloat = 0
    
    override var contentLabelTopMargin: CGFloat {
        return fullnameHeight + contentMargin.top + Quote.height + Quote.backgroundMargin.vertical
    }
    
    override var backgroundWidth: CGFloat {
        return max(super.backgroundWidth, quoteMaxWidth)
    }
    
    override func didSetStyle() {
        guard let quote = quote else {
            return
        }
        let paddedQuoteIconWidth = quote.icon == nil ? 0 : Quote.iconSize.width + Quote.iconTrailingMargin
        let quoteImageWidth = (quote.imageUrl == nil && quote.thumbnail == nil) ? 0 : Quote.imageSize.width
        let maxTitleWidth = maxContentWidth
            - Quote.backgroundMargin.horizontal
            - Quote.contentMargin.horizontal
            - quoteImageWidth
        let maxSubtitleWidth = maxContentWidth
            - Quote.backgroundMargin.horizontal
            - Quote.contentMargin.horizontal
            - paddedQuoteIconWidth
            - quoteImageWidth
        
        var titleWidth: CGFloat = 0
        titleWidth = (quote.title as NSString).size(withAttributes: [.font: Quote.titleFont]).width
        titleWidth = ceil(titleWidth)
        titleWidth = min(maxTitleWidth, titleWidth)
        
        var subtitleWidth: CGFloat = 0
        subtitleWidth = (quote.subtitle as NSString).size(withAttributes: [.font: Quote.subtitleFont]).width
        subtitleWidth = ceil(subtitleWidth)
        subtitleWidth = min(maxSubtitleWidth, subtitleWidth)
        
        quoteMaxWidth = max(titleWidth + quoteImageWidth, paddedQuoteIconWidth + subtitleWidth + quoteImageWidth)
            + Quote.contentMargin.horizontal
            + Quote.backgroundMargin.horizontal
        
        super.didSetStyle()
        
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
                                      height: Quote.height)
        
        let secondLineHeight = max(Quote.iconSize.height, Quote.subtitleHeight)
        let quoteTitleVerticalMargin = quoteBackgroundFrame.height
            - Quote.titleHeight
            - Quote.linesVerticalSpacing
            - secondLineHeight
        let quoteTitleTopMargin = quoteTitleVerticalMargin / 2
        
        quoteTitleFrame = CGRect(x: quoteBackgroundFrame.origin.x + Quote.contentMargin.leading,
                                 y: quoteBackgroundFrame.origin.y + quoteTitleTopMargin,
                                 width: titleWidth,
                                 height: Quote.titleHeight)
        
        let quoteIconOrigin = CGPoint(x: quoteTitleFrame.origin.x,
                                      y: quoteTitleFrame.maxY + Quote.linesVerticalSpacing + (secondLineHeight - Quote.iconSize.height) / 2)
        if quote.icon == nil {
            quoteIconFrame = CGRect(origin: quoteIconOrigin, size: .zero)
        } else {
            quoteIconFrame = CGRect(origin: quoteIconOrigin, size: Quote.iconSize)
        }
        
        quoteSubtitleFrame = CGRect(x: quoteTitleFrame.origin.x + paddedQuoteIconWidth,
                                    y: quoteTitleFrame.maxY + Quote.linesVerticalSpacing + (secondLineHeight - Quote.subtitleHeight) / 2,
                                    width: subtitleWidth,
                                    height: Quote.subtitleHeight)
        let quoteImageOrigin = CGPoint(x: quoteBackgroundFrame.maxX - Quote.imageSize.width,
                                       y: quoteBackgroundFrame.origin.y)
        let quoteImageSize = (quote.imageUrl == nil && quote.thumbnail == nil) ? .zero : Quote.imageSize
        quoteImageFrame = CGRect(origin: quoteImageOrigin, size: quoteImageSize)
    }
    
}

