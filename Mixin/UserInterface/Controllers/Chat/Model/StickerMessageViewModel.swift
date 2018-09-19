import UIKit

class StickerMessageViewModel: DetailInfoMessageViewModel {

    static let timeMargin = Margin(leading: 2, trailing: 2, top: 4, bottom: 4)
    static let maxWH: CGFloat = 120
    static let minWH: CGFloat = 48
    
    internal(set) var contentFrame = CGRect.zero

    override var contentMargin: Margin {
        return Margin(leading: 17, trailing: 0, top: 2, bottom: 2)
    }
    
    private let contentSize: CGSize

    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        if let assetWidth = message.assetWidth, let assetHeight = message.assetHeight, assetWidth > 0, assetHeight > 0 {
            let width = CGFloat(assetWidth / 2)
            let height = CGFloat(assetHeight / 2)
            let ratio = width / height
            var targetSize = CGSize.zero

            if min(width, height) < StickerMessageViewModel.minWH {
                if width > height {
                    targetSize = CGSize(width: StickerMessageViewModel.minWH * ratio, height: StickerMessageViewModel.minWH)
                } else {
                    targetSize = CGSize(width: StickerMessageViewModel.minWH, height: StickerMessageViewModel.minWH / ratio)
                }
            }

            if max(width, height) > StickerMessageViewModel.maxWH || max(targetSize.width, targetSize.height) > StickerMessageViewModel.maxWH {
                if width > height {
                    contentSize = CGSize(width: StickerMessageViewModel.maxWH, height: StickerMessageViewModel.maxWH / ratio)
                } else {
                    contentSize = CGSize(width: StickerMessageViewModel.maxWH * ratio, height: StickerMessageViewModel.maxWH)
                }
            } else {
                contentSize = CGSize(width: width, height: height)
            }
        } else {
            contentSize = CGSize(width: StickerMessageViewModel.minWH, height: StickerMessageViewModel.minWH)
        }
        super.init(message: message, style: style, fits: layoutWidth)
        backgroundImage = nil
    }
    
    override func didSetStyle() {
        let bottomSeparatorHeight = style.contains(.bottomSeparator) ? MessageViewModel.bottomSeparatorHeight : 0
        let fullnameHeight = style.contains(.fullname) ? fullnameFrame.height : 0
        let timeMargin = StickerMessageViewModel.timeMargin
        if style.contains(.received) {
            contentFrame = CGRect(x: contentMargin.leading,
                                  y: contentMargin.top,
                                  width: contentSize.width,
                                  height: contentSize.height)
            if style.contains(.fullname) {
                contentFrame.origin.y += fullnameHeight
            }
            backgroundImageFrame = CGRect(x: contentFrame.origin.x - DetailInfoMessageViewModel.margin.leading + timeMargin.trailing,
                                          y: contentMargin.vertical + contentFrame.origin.y,
                                          width: contentSize.width + contentMargin.horizontal,
                                          height: contentSize.height + contentMargin.vertical)
        } else {
            contentFrame = CGRect(x: layoutWidth - contentMargin.leading - contentSize.width,
                                  y: contentMargin.top,
                                  width: contentSize.width,
                                  height: contentSize.height)
            backgroundImageFrame = CGRect(x: contentFrame.origin.x - DetailInfoMessageViewModel.margin.trailing + timeMargin.leading,
                                          y: contentMargin.vertical + contentFrame.origin.y,
                                          width: contentSize.width + contentMargin.horizontal,
                                          height: contentSize.height + contentMargin.vertical)
        }
        super.didSetStyle()
        fullnameFrame.size.width = min(fullnameWidth, maxContentWidth)
        if style.contains(.received) {
            timeFrame.origin.x = max(timeFrame.origin.x, contentFrame.origin.x)
        }
        timeFrame.origin.y = contentFrame.maxY + contentMargin.bottom + timeMargin.top
        statusFrame.origin = CGPoint(x: timeFrame.maxX + DetailInfoMessageViewModel.statusLeftMargin,
                                     y: timeFrame.origin.y + (timeFrame.height - statusFrame.height) / 2)
        cellHeight = fullnameHeight + contentFrame.size.height + contentMargin.vertical + timeFrame.height + timeMargin.vertical + bottomSeparatorHeight
    }
    
}
