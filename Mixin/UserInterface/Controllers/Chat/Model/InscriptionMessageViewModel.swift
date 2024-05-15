import Foundation

class InscriptionMessageViewModel: DetailInfoMessageViewModel {
    
    override class var bubbleImageSet: BubbleImageSet.Type {
        NoTailLightBubbleImageSet.self
    }
    
    private(set) var leadingConstant: CGFloat = 0
    private(set) var trailingConstant: CGFloat = 0
    
    override func layout(width: CGFloat, style: Style) {
        if style.contains(.received) {
            leadingConstant = 9
            trailingConstant = -2
        } else {
            leadingConstant = 2
            trailingConstant = -9
        }
        super.layout(width: width, style: style)
        let contentWidth: CGFloat = 271
        let contentHeight: CGFloat = 116
        let fullnameHeight: CGFloat = style.contains(.fullname) ? fullnameFrame.height : 0
        let x: CGFloat
        if style.contains(.received) {
            x = Self.bubbleMargin.leading
        } else {
            x = width - Self.bubbleMargin.leading - contentWidth
        }
        backgroundImageFrame = CGRect(x: x, y: fullnameHeight, width: contentWidth, height: contentHeight)
        cellHeight = fullnameHeight + backgroundImageFrame.height + timeFrame.height + timeMargin.bottom + bottomSeparatorHeight
        layoutDetailInfo(insideBackgroundImage: false, backgroundImageFrame: backgroundImageFrame)
        layoutQuotedMessageIfPresent()
        if !style.contains(.received) {
            timeFrame.origin.x += statusFrame.width
        }
    }
    
}
