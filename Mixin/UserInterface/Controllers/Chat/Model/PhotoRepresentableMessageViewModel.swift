import UIKit
import MixinServices

class PhotoRepresentableMessageViewModel: DetailInfoMessageViewModel, BackgroundedTrailingInfoViewModel {
    
    let contentRatio: CGSize
    
    var presentationFrame = CGRect.zero
    var trailingInfoBackgroundFrame = CGRect.zero
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
        if style.contains(.received) {
            presentationFrame = CGRect(x: bubbleMargin.leading,
                                       y: bubbleMargin.top,
                                       width: presentationSize.width,
                                       height: presentationSize.height)
            if style.contains(.fullname) {
                presentationFrame.origin.y += fullnameHeight
            }
        } else {
            presentationFrame = CGRect(x: width - bubbleMargin.leading - presentationSize.width,
                                       y: bubbleMargin.top,
                                       width: presentationSize.width,
                                       height: presentationSize.height)
        }
        backgroundImageFrame = presentationFrame
        cellHeight = fullnameHeight + backgroundImageFrame.size.height + bottomSeparatorHeight
        layoutDetailInfo(backgroundImageFrame: backgroundImageFrame)
        layoutTrailingInfoBackgroundFrame()
    }
    
    func update(mediaUrl: String?, mediaSize: Int64?, mediaDuration: Int64?) {
        message.mediaUrl = mediaUrl
        message.mediaSize = mediaSize
        message.mediaDuration = mediaDuration
    }
    
}
