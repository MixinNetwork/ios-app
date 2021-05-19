import UIKit
import MixinServices

class StickerMessageViewModel: DetailInfoMessageViewModel {
    
    private enum SideLength {
        static let max: CGFloat = 120
        static let min: CGFloat = 64
    }
    
    override var contentMargin: Margin {
        return Margin(leading: 17, trailing: 0, top: 2, bottom: 2)
    }
    
    var contentFrame = CGRect.zero
    
    private let contentSize: CGSize
    
    override init(message: MessageItem) {
        let assetWidth, assetHeight: Int?
        if let width = message.assetWidth, let height = message.assetHeight, width > 0, height > 0 {
            (assetWidth, assetHeight) = (width, height)
        } else if let width = message.mediaWidth, let height = message.mediaHeight, width > 0, height > 0 {
            (assetWidth, assetHeight) = (width, height)
        } else {
            (assetWidth, assetHeight) = (nil, nil)
        }
        if let assetWidth = assetWidth, let assetHeight = assetHeight {
            let assetSize = CGSize(width: assetWidth / 2, height: assetHeight / 2)
            let ratio = assetSize.width / assetSize.height
            
            let contentSize: CGSize
            if max(assetSize.width, assetSize.height) > SideLength.max {
                if ratio > 1 {
                    contentSize = CGSize(width: SideLength.max, height: SideLength.max / ratio)
                } else {
                    contentSize = CGSize(width: SideLength.max * ratio, height: SideLength.max)
                }
            } else if min(assetSize.width, assetSize.height) < SideLength.min {
                let maxRatio = SideLength.max / SideLength.min
                if ratio <= (1 / maxRatio) {
                    // e.g. w*h is 1*100
                    contentSize = CGSize(width: SideLength.max * ratio, height: SideLength.max)
                } else if ratio < 1 {
                    // e.g. w*h is 2*3
                    contentSize = CGSize(width: SideLength.min, height: SideLength.min / ratio)
                } else if ratio == 1 {
                    // e.g. w*h is 2*2
                    contentSize = CGSize(width: SideLength.min, height: SideLength.min)
                } else if ratio < maxRatio {
                    // e.g. w*h is 3*2
                    contentSize = CGSize(width: SideLength.min * ratio, height: SideLength.min)
                } else {
                    // e.g. w*h is 100*1
                    contentSize = CGSize(width: SideLength.max, height: SideLength.max / ratio)
                }
            } else {
                contentSize = assetSize
            }
            
            self.contentSize = round(contentSize)
        } else {
            self.contentSize = CGSize(width: SideLength.min, height: SideLength.min)
        }
        super.init(message: message)
        backgroundImage = nil
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        let timeMargin = Margin(leading: -6, trailing: -6, top: 4, bottom: 4)
        let bottomSeparatorHeight = style.contains(.bottomSeparator) ? MessageViewModel.bottomSeparatorHeight : 0
        let fullnameHeight = style.contains(.fullname) ? fullnameFrame.height : 0
        if style.contains(.received) {
            contentFrame = CGRect(x: contentMargin.leading,
                                  y: contentMargin.top,
                                  width: contentSize.width,
                                  height: contentSize.height)
            if style.contains(.fullname) {
                contentFrame.origin.y += fullnameHeight
            }
        } else {
            contentFrame = CGRect(x: width - contentMargin.leading - contentSize.width,
                                  y: contentMargin.top,
                                  width: contentSize.width,
                                  height: contentSize.height)
        }
        layoutDetailInfo(backgroundImageFrame: backgroundImageFrame)
        fullnameFrame.size.width = min(fullnameFrame.size.width, maxContentWidth)
        let timeOffset = style.contains(.received)
            ? timeMargin.leading
            : (timeMargin.trailing - DetailInfoMessageViewModel.statusLeftMargin - statusFrame.width)
        timeFrame.origin = CGPoint(x: contentFrame.maxX - timeFrame.width + timeOffset,
                                   y: contentFrame.maxY + contentMargin.bottom + timeMargin.top)
        layoutEncryptedIconFrame()
        layoutForwarderIcon()
        statusFrame.origin = CGPoint(x: timeFrame.maxX + DetailInfoMessageViewModel.statusLeftMargin,
                                     y: timeFrame.origin.y + (timeFrame.height - statusFrame.height) / 2)
        cellHeight = fullnameHeight
            + contentFrame.size.height
            + contentMargin.vertical
            + timeFrame.height
            + timeMargin.vertical
            + bottomSeparatorHeight
    }
    
}
