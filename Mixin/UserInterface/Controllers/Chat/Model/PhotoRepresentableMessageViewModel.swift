import UIKit

class PhotoRepresentableMessageViewModel: DetailInfoMessageViewModel {

    static let contentWidth: CGFloat = 220
    static let maxHeight: CGFloat = UIScreen.main.bounds.height / 2
    static let leftShadowImage = #imageLiteral(resourceName: "ic_chat_shadow_left")
    static let rightShadowImage = #imageLiteral(resourceName: "ic_chat_shadow_right")
    static let rightWithTailShadowImage = #imageLiteral(resourceName: "ic_chat_shadow_right_tail")
    
    let aspectRatio: CGSize
    
    internal(set) var contentFrame = CGRect.zero
    internal(set) var shadowImage: UIImage?
    internal(set) var shadowImageOrigin = CGPoint.zero
    internal(set) var operationButtonStyle = NetworkOperationButton.Style.finished(showPlayIcon: false)
    internal(set) var layoutPosition = PhotoMessageCell.VerticalPositioningImageView.Position.center
    
    override var contentMargin: Margin {
        return Margin(leading: 9, trailing: 5, top: 4, bottom: 6)
    }
    
    private let contentSize: CGSize

    override var statusNormalTintColor: UIColor {
        return .white
    }
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        let contentWidth = PhotoRepresentableMessageViewModel.contentWidth
        let mediaWidth = abs(CGFloat(message.mediaWidth ?? 1))
        var mediaHeight = abs(CGFloat(message.mediaHeight ?? 1))
        if mediaHeight == 0 {
            mediaHeight = 1
        }
        let ratio = mediaWidth / mediaHeight
        contentSize = CGSize(width: contentWidth,
                             height: min(PhotoRepresentableMessageViewModel.maxHeight, contentWidth / ratio))
        aspectRatio = CGSize(width: mediaWidth, height: mediaHeight)
        super.init(message: message, style: style, fits: layoutWidth)
    }
    
    override func didSetStyle() {
        let backgroundImageMargin = MessageViewModel.backgroundImageMargin
        let bottomSeparatorHeight = style.contains(.bottomSeparator) ? MessageViewModel.bottomSeparatorHeight : 0
        let fullnameHeight = style.contains(.fullname) ? fullnameFrame.height : 0
        if style.contains(.received) {
            shadowImage = PhotoRepresentableMessageViewModel.leftShadowImage
        } else {
            if style.contains(.tail) {
                shadowImage = PhotoRepresentableMessageViewModel.rightWithTailShadowImage
            } else {
                shadowImage = PhotoRepresentableMessageViewModel.rightShadowImage
            }
        }
        let shadowImageSize = shadowImage?.size ?? .zero
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
        backgroundImageFrame = CGRect(origin: .zero, size: contentFrame.size)
        cellHeight = fullnameHeight + backgroundImageFrame.size.height + bottomSeparatorHeight
        super.didSetStyle()
        timeFrame.origin.x += contentFrame.origin.x
        timeFrame.origin.y += fullnameHeight
        if !style.contains(.received) {
            statusFrame.origin.x = timeFrame.maxX + DetailInfoMessageViewModel.statusLeftMargin
        }
        statusFrame.origin.y += fullnameHeight
    }

}
