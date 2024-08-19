import UIKit
import MixinServices

class ContactMessageViewModel: CardMessageViewModel {
    
    static let titleSpacing: CGFloat = 6
    
    override class var supportsQuoting: Bool {
        true
    }
    
    let verifiedImage: UIImage?
    
    override init(message: MessageItem) {
        verifiedImage = UserBadgeIcon.image(
            membership: message.sharedUserMembership,
            isVerified: message.sharedUserIsVerified ?? false,
            appID: message.sharedUserAppId
        )
        super.init(message: message)
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        let fullnameWidth = ((message.sharedUserFullName ?? "") as NSString)
            .size(withAttributes: [NSAttributedString.Key.font: MessageFontSet.cardTitle.scaled])
            .width
        let iconWidth: CGFloat = {
            if let image = verifiedImage {
                return ContactMessageViewModel.titleSpacing + image.size.width
            } else {
                return 0
            }
        }()
        let idWidth = ((message.sharedUserIdentityNumber ?? "") as NSString)
            .size(withAttributes: [NSAttributedString.Key.font: MessageFontSet.cardSubtitle.scaled])
            .width
        contentWidth = Self.leftViewSideLength
            + Self.spacing
            + ceil(max(fullnameWidth + iconWidth, idWidth))
        super.layout(width: width, style: style)
    }
    
}
