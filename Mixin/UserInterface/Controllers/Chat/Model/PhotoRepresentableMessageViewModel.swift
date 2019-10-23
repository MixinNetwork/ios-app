import UIKit

class PhotoRepresentableMessageViewModel: DetailInfoMessageViewModel {

    static let contentWidth: CGFloat = 220
    static let maxHeight: CGFloat = UIScreen.main.bounds.height / 2
    static let shadowImage = UIImage(named: "ic_chat_shadow")
    
    let contentSize: CGSize
    let aspectRatio: CGSize
    
    var contentFrame = CGRect.zero
    var shadowImageOrigin = CGPoint.zero
    var operationButtonStyle = NetworkOperationButton.Style.finished(showPlayIcon: false)
    var layoutPosition = VerticalPositioningImageView.Position.center
    
    override var contentMargin: Margin {
        return Margin(leading: 9, trailing: 5, top: 4, bottom: 6)
    }
    
    override var statusNormalTintColor: UIColor {
        return .white
    }
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        let contentWidth = PhotoRepresentableMessageViewModel.contentWidth
        let mediaWidth = abs(CGFloat(message.mediaWidth ?? 0))
        let mediaHeight = abs(CGFloat(message.mediaHeight ?? 0))
        if mediaWidth < 1 || mediaHeight < 1 {
            contentSize = CGSize(width: contentWidth, height: contentWidth)
            aspectRatio = contentSize
        } else {
            let height = min(PhotoRepresentableMessageViewModel.maxHeight, contentWidth / mediaWidth * mediaHeight)
            contentSize = CGSize(width: contentWidth, height: height)
            aspectRatio = CGSize(width: mediaWidth, height: mediaHeight)
        }
        super.init(message: message, style: style, fits: layoutWidth)
    }
    
    override func layout() {
        let backgroundImageMargin = MessageViewModel.backgroundImageMargin
        let bottomSeparatorHeight = style.contains(.bottomSeparator) ? MessageViewModel.bottomSeparatorHeight : 0
        let fullnameHeight = style.contains(.fullname) ? fullnameFrame.height : 0
        let shadowImageSize = PhotoRepresentableMessageViewModel.shadowImage?.size ?? .zero
        if style.contains(.received) {
            contentFrame = CGRect(x: backgroundImageMargin.leading,
                                  y: backgroundImageMargin.top,
                                  width: contentSize.width,
                                  height: contentSize.height)
            shadowImageOrigin = CGPoint(x: contentFrame.maxX - shadowImageSize.width,
                                        y: contentFrame.maxY - shadowImageSize.height)
            if style.contains(.fullname) {
                contentFrame.origin.y += fullnameHeight
                shadowImageOrigin.y += fullnameHeight
            }
        } else {
            contentFrame = CGRect(x: layoutWidth - backgroundImageMargin.leading - contentSize.width,
                                  y: backgroundImageMargin.top,
                                  width: contentSize.width,
                                  height: contentSize.height)
            shadowImageOrigin = CGPoint(x: contentFrame.maxX - shadowImageSize.width,
                                        y: contentFrame.maxY - shadowImageSize.height)
        }
        backgroundImageFrame = contentFrame
        cellHeight = fullnameHeight + backgroundImageFrame.size.height + bottomSeparatorHeight
        super.layout()
    }
    
    func update(mediaUrl: String?, mediaSize: Int64?, mediaDuration: Int64?) {
        message.mediaUrl = mediaUrl
        message.mediaSize = mediaSize
        message.mediaDuration = mediaDuration
    }
    
}
