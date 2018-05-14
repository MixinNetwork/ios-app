import UIKit

class PhotoMessageViewModel: DetailInfoMessageViewModel, ProgressInspectableMessageViewModel {
    
    static let contentWidth: CGFloat = 220
    static let maxHeight: CGFloat = UIScreen.main.bounds.height / 2
    static let leftShadowImage = #imageLiteral(resourceName: "ic_chat_shadow_left")
    static let rightShadowImage = #imageLiteral(resourceName: "ic_chat_shadow_right")
    static let rightWithTailShadowImage = #imageLiteral(resourceName: "ic_chat_shadow_right_tail")
    
    internal(set) var contentFrame = CGRect.zero
    internal(set) var shadowImage: UIImage?
    internal(set) var shadowImageOrigin = CGPoint.zero
    internal(set) var networkOperationButtonStyle = NetworkOperationButton.Style.finished(showPlayIcon: false)

    override lazy var contentMargin: Margin = {
        Margin(leading: 9, trailing: 5, top: 4, bottom: 6)
    }()
    
    private let contentSize: CGSize
    
    var progress: Double?

    override var statusNormalTintColor: UIColor {
        return .white
    }
    
    var mediaStatus: String? {
        get {
            return message.mediaStatus
        }
        set {
            let sentByMe = message.userId == AccountAPI.shared.accountUserId
            if let newValue = newValue {
                switch newValue {
                case MediaStatus.PENDING.rawValue:
                    networkOperationButtonStyle = .busy(progress:0)
                case MediaStatus.CANCELED.rawValue:
                    if sentByMe {
                        networkOperationButtonStyle = .upload
                    } else {
                        networkOperationButtonStyle = .download
                    }
                case MediaStatus.DONE.rawValue:
                    networkOperationButtonStyle = .finished(showPlayIcon: false)
                case MediaStatus.EXPIRED.rawValue:
                    networkOperationButtonStyle = .expired
                default:
                    break
                }
            } else {
                networkOperationButtonStyle = .finished(showPlayIcon: false)
            }
            if newValue != MediaStatus.PENDING.rawValue {
                progress = nil
            }
            message.mediaStatus = newValue
        }
    }
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        let contentWidth = PhotoMessageViewModel.contentWidth
        let mediaWidth = CGFloat(message.mediaWidth ?? 1)
        var mediaHeight = CGFloat(message.mediaHeight ?? 1)
        if mediaHeight == 0 {
            mediaHeight = 1
        }
        let ratio = mediaWidth / mediaHeight
        contentSize = CGSize(width: contentWidth,
                             height: min(PhotoMessageViewModel.maxHeight, contentWidth / ratio))
        super.init(message: message, style: style, fits: layoutWidth)
        mediaStatus = message.mediaStatus
    }
    
    override func didSetStyle() {
        let backgroundImageMargin = MessageViewModel.backgroundImageMargin
        let bottomSeparatorHeight = style.contains(.hasBottomSeparator) ? MessageViewModel.bottomSeparatorHeight : 0
        let fullnameHeight = style.contains(.showFullname) ? fullnameFrame.height : 0
        if style.contains(.sent) {
            if style.contains(.hasTail) {
                shadowImage = PhotoMessageViewModel.rightWithTailShadowImage
            } else {
                shadowImage = PhotoMessageViewModel.rightShadowImage
            }
        } else {
            shadowImage = PhotoMessageViewModel.leftShadowImage
        }
        let shadowImageSize = shadowImage?.size ?? .zero
        if style.contains(.received) {
            contentFrame = CGRect(x: backgroundImageMargin.leading,
                                  y: backgroundImageMargin.top,
                                  width: contentSize.width,
                                  height: contentSize.height)
            shadowImageOrigin = CGPoint(x: contentFrame.maxX - shadowImageSize.width,
                                        y: contentFrame.maxY - shadowImageSize.height)
            if style.contains(.showFullname) {
                contentFrame.origin.y += fullnameHeight
                shadowImageOrigin.y += fullnameHeight
            }
        } else if style.contains(.sent) {
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
        if style.contains(.sent) {
            statusFrame.origin.x = timeFrame.maxX + DetailInfoMessageViewModel.statusLeftMargin
        }
        statusFrame.origin.y += fullnameHeight
    }
    
}
