import UIKit

class StreamMessageViewModel: TextMessageViewModel {
    
    private let thumbnailMargin = Margin(leading: 9, trailing: 2, top: 1, bottom: 0)
    
    override class var bubbleImageProvider: BubbleImageProvider.Type {
        return LightRightBubbleImageProvider.self
    }
    
    var thumbnailFrame = CGRect.zero
    var badgeOrigin = CGPoint.zero
    
    var contentWidth: CGFloat {
        return PhotoRepresentableMessageViewModel.contentWidth
    }
    
    var textWidth: CGFloat {
        return contentWidth - timeStatusSize.width
    }
    
    override func linksMap(from attributedString: NSAttributedString) -> [NSRange: URL] {
        return [:]
    }
    
    override func typeset(attributedString: CFAttributedString) -> TypesetResult {
        let typesetter = CTTypesetterCreateWithAttributedString(attributedString)
        let lineCharacterCount = CTTypesetterSuggestLineBreak(typesetter, 0, Double(contentWidth))
        guard lineCharacterCount > 0 else {
            return ([], [], [], 0)
        }
        let lineRange = CFRange(location: 0, length: lineCharacterCount)
        var line = CTTypesetterCreateLine(typesetter, lineRange)
        let ellipsis = NSMutableAttributedString(string: "…")
        setDefaultAttributes(on: ellipsis)
        let truncationToken = CTLineCreateWithAttributedString(ellipsis as CFAttributedString)
        let textWidth = self.textWidth
        if let truncated = CTLineCreateTruncatedLine(line, Double(textWidth), .end, truncationToken) {
            line = truncated
        }
        let lineOrigin = CGPoint(x: 0, y: 4)
        textSize = CGSize(width: textWidth, height: type(of: self).lineHeight)
        return ([line], [lineOrigin], [lineRange], textWidth)
    }
    
    override func didSetStyle() {
        super.didSetStyle()
        let ratio: CGFloat
        if let width = message.mediaWidth, let height = message.mediaHeight {
            ratio = CGFloat(width) / CGFloat(height)
        } else {
            ratio = 16 / 9
        }
        let thumbnailWidth = backgroundImageFrame.width - thumbnailMargin.horizontal
        let thumbnailHeight = floor(thumbnailWidth / ratio)
        let thumbnailSize = CGSize(width: thumbnailWidth, height: thumbnailHeight)
        let thumnailOrigin: CGPoint
        if style.contains(.received) {
            thumnailOrigin = CGPoint(x: backgroundImageFrame.origin.x + thumbnailMargin.leading,
                                     y: backgroundImageFrame.origin.y + thumbnailMargin.top)
        } else {
            thumnailOrigin = CGPoint(x: backgroundImageFrame.origin.x + thumbnailMargin.trailing,
                                     y: backgroundImageFrame.origin.y + thumbnailMargin.top)
        }
        thumbnailFrame = CGRect(origin: thumnailOrigin, size: thumbnailSize)
        badgeOrigin = CGPoint(x: thumnailOrigin.x + 8, y: thumnailOrigin.y + 8)
        backgroundImageFrame.size.height += thumbnailHeight
        contentLabelFrame.origin.y += thumbnailHeight
        timeFrame.origin.y += thumbnailHeight
        statusFrame.origin.y += thumbnailHeight
        cellHeight += thumbnailHeight
    }
    
}
