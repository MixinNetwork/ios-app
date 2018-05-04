import UIKit

class StickerMessageViewModel: DetailInfoMessageViewModel {

    static let maxHeight: CGFloat = UIScreen.main.bounds.height / 2
    static let timeMargin = Margin(leading: 2, trailing: 2, top: 4, bottom: 4)
    static let maxWidth: CGFloat = 120
    
    internal(set) var contentFrame = CGRect.zero

    override lazy var contentMargin: Margin = {
        Margin(leading: 17, trailing: 0, top: 2, bottom: 2)
    }()
    
    private let contentSize: CGSize

    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        if let assetWidth = message.assetWidth, var assetHeight = message.assetHeight {
            if assetHeight == 0 {
                assetHeight = 1
            }
            let width = min(StickerMessageViewModel.maxWidth, CGFloat(assetWidth) / UIScreen.main.scale)
            let ratio = CGFloat(assetWidth) / CGFloat(assetHeight)
            contentSize = ceil(CGSize(width: width, height: width / ratio))
        } else {
            contentSize = CGSize(width: StickerMessageViewModel.maxWidth, height: StickerMessageViewModel.maxWidth)
        }
        super.init(message: message, style: style, fits: layoutWidth)
        backgroundImage = nil
    }
    
    override func didSetStyle() {
        let bottomSeparatorHeight = style.contains(.hasBottomSeparator) ? MessageViewModel.bottomSeparatorHeight : 0
        let fullnameHeight = style.contains(.showFullname) ? fullnameFrame.height : 0
        let timeMargin = StickerMessageViewModel.timeMargin
        if style.contains(.received) {
            contentFrame = CGRect(x: contentMargin.leading,
                                  y: contentMargin.top,
                                  width: contentSize.width,
                                  height: contentSize.height)
            if style.contains(.showFullname) {
                contentFrame.origin.y += fullnameHeight
            }
            backgroundImageFrame = CGRect(x: contentFrame.origin.x - DetailInfoMessageViewModel.margin.leading + timeMargin.trailing,
                                          y: contentMargin.vertical + contentFrame.origin.y,
                                          width: contentSize.width + contentMargin.horizontal,
                                          height: contentSize.height + contentMargin.vertical)
        } else if style.contains(.sent) {
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
        timeFrame.origin.y = contentFrame.maxY + contentMargin.bottom + timeMargin.top
        statusFrame.origin = CGPoint(x: timeFrame.maxX + DetailInfoMessageViewModel.statusLeftMargin,
                                     y: timeFrame.origin.y + (timeFrame.height - statusFrame.height) / 2)
        cellHeight = fullnameHeight + contentFrame.size.height + contentMargin.vertical + timeFrame.height + timeMargin.vertical + bottomSeparatorHeight
    }
    
}
