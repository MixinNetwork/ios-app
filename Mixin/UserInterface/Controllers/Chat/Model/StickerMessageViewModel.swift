import UIKit

class StickerMessageViewModel: DetailInfoMessageViewModel {
    
    private enum SideLength {
        static let max: CGFloat = 120
        static let min: CGFloat = 48
    }
    
    override var contentMargin: Margin {
        return Margin(leading: 17, trailing: 0, top: 2, bottom: 2)
    }
    
    var contentFrame = CGRect.zero
    
    private let timeMargin = Margin(leading: -6, trailing: -6, top: 4, bottom: 4)
    private let contentSize: CGSize
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        if let assetWidth = message.assetWidth, let assetHeight = message.assetHeight, assetWidth > 0, assetHeight > 0 {
            let width = CGFloat(assetWidth / 2)
            let height = CGFloat(assetHeight / 2)
            let ratio = width / height
            var targetSize = CGSize.zero
            
            if min(width, height) < SideLength.min {
                if width > height {
                    targetSize = CGSize(width: SideLength.min * ratio, height: SideLength.min)
                } else {
                    targetSize = CGSize(width: SideLength.min, height: SideLength.min / ratio)
                }
            }
            
            if max(width, height) > SideLength.max || max(targetSize.width, targetSize.height) > SideLength.max {
                if width > height {
                    contentSize = CGSize(width: SideLength.max, height: SideLength.max / ratio)
                } else {
                    contentSize = CGSize(width: SideLength.max * ratio, height: SideLength.max)
                }
            } else {
                contentSize = CGSize(width: width, height: height)
            }
        } else {
            contentSize = CGSize(width: SideLength.min, height: SideLength.min)
        }
        super.init(message: message, style: style, fits: layoutWidth)
        backgroundImage = nil
    }
    
    override func layout() {
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
            contentFrame = CGRect(x: layoutWidth - contentMargin.leading - contentSize.width,
                                  y: contentMargin.top,
                                  width: contentSize.width,
                                  height: contentSize.height)
        }
        super.layout()
        fullnameFrame.size.width = min(fullnameWidth, maxContentWidth)
        let timeOffset = style.contains(.received)
            ? timeMargin.leading
            : (timeMargin.trailing - DetailInfoMessageViewModel.statusLeftMargin - statusFrame.width)
        timeFrame.origin = CGPoint(x: contentFrame.maxX - timeFrame.width + timeOffset,
                                   y: contentFrame.maxY + contentMargin.bottom + timeMargin.top)
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
