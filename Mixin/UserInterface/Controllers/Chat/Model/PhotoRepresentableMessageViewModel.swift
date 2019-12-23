import UIKit
import MixinServices

class PhotoRepresentableMessageViewModel: DetailInfoMessageViewModel {
    
    static let shadowImage = R.image.ic_chat_shadow()
    
    let contentRatio: CGSize
    
    var contentFrame = CGRect.zero
    var shadowImageOrigin = CGPoint.zero
    var operationButtonStyle = NetworkOperationButton.Style.finished(showPlayIcon: false)
    var layoutPosition = VerticalPositioningImageView.Position.center
    
    // Presentation width is fixed at 220
    private(set) var presentationSize = CGSize(width: 220, height: 220)
    
    override var contentMargin: Margin {
        return Margin(leading: 9, trailing: 5, top: 4, bottom: 6)
    }
    
    override var statusNormalTintColor: UIColor {
        return .white
    }
    
    private var maxPresentationHeight: CGFloat {
        return performSynchronouslyOnMainThread {
            AppDelegate.current.window.bounds.height / 2
        }
    }
    
    override init(message: MessageItem) {
        let mediaWidth = abs(CGFloat(message.mediaWidth ?? 0))
        let mediaHeight = abs(CGFloat(message.mediaHeight ?? 0))
        if mediaWidth < 1 || mediaHeight < 1 {
            contentRatio = CGSize(width: 1, height: 1)
        } else {
            contentRatio = CGSize(width: mediaWidth, height: mediaHeight)
        }
        super.init(message: message)
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        let ratio = contentRatio.width / contentRatio.height
        presentationSize.height = min(maxPresentationHeight, round(presentationSize.width / ratio))
        let bubbleMargin = DetailInfoMessageViewModel.bubbleMargin
        let bottomSeparatorHeight = style.contains(.bottomSeparator) ? MessageViewModel.bottomSeparatorHeight : 0
        let fullnameHeight = style.contains(.fullname) ? fullnameFrame.height : 0
        let shadowImageSize = PhotoRepresentableMessageViewModel.shadowImage?.size ?? .zero
        if style.contains(.received) {
            contentFrame = CGRect(x: bubbleMargin.leading,
                                  y: bubbleMargin.top,
                                  width: presentationSize.width,
                                  height: presentationSize.height)
            shadowImageOrigin = CGPoint(x: contentFrame.maxX - shadowImageSize.width,
                                        y: contentFrame.maxY - shadowImageSize.height)
            if style.contains(.fullname) {
                contentFrame.origin.y += fullnameHeight
                shadowImageOrigin.y += fullnameHeight
            }
        } else {
            contentFrame = CGRect(x: width - bubbleMargin.leading - presentationSize.width,
                                  y: bubbleMargin.top,
                                  width: presentationSize.width,
                                  height: presentationSize.height)
            shadowImageOrigin = CGPoint(x: contentFrame.maxX - shadowImageSize.width,
                                        y: contentFrame.maxY - shadowImageSize.height)
        }
        backgroundImageFrame = contentFrame
        cellHeight = fullnameHeight + backgroundImageFrame.size.height + bottomSeparatorHeight
        layoutDetailInfo(backgroundImageFrame: backgroundImageFrame)
    }
    
    func update(mediaUrl: String?, mediaSize: Int64?, mediaDuration: Int64?) {
        message.mediaUrl = mediaUrl
        message.mediaSize = mediaSize
        message.mediaDuration = mediaDuration
    }
    
}
