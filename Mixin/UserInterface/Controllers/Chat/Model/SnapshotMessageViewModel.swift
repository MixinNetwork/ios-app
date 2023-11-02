import UIKit
import MixinServices

class SnapshotMessageViewModel: DetailInfoMessageViewModel {
    
    override class var bubbleImageSet: BubbleImageSet.Type {
        return LightRightBubbleImageSet.self
    }
    
    let amount: String?
    
    private(set) var leadingConstant: CGFloat = 0
    private(set) var trailingConstant: CGFloat = 0
    
    override var timeMargin: Margin {
        Margin(leading: 16, trailing: 10, top: 0, bottom: 2)
    }
    
    override init(message: MessageItem) {
        amount = CurrencyFormatter.localizedString(from: message.snapshotAmount, format: .precision, sign: .whenNegative)
        super.init(message: message)
    }
    
    override func layout(width: CGFloat, style: Style) {
        if style.contains(.received) {
            leadingConstant = 10
            trailingConstant = -2
        } else {
            leadingConstant = 2
            trailingConstant = -9
        }
        super.layout(width: width, style: style)
        let contentWidth: CGFloat = 190
        let contentHeight: CGFloat
        if let memo = message.snapshotMemo, !memo.isEmpty {
            contentHeight = 110
        } else {
            contentHeight = 96
        }
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
