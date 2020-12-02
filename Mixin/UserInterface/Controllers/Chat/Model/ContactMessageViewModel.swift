import UIKit
import MixinServices

class ContactMessageViewModel: CardMessageViewModel {
    
    static let titleSpacing: CGFloat = 6
    static let fullnameFontSet = MessageFontSet(style: .body)
    static let idFontSet = MessageFontSet(size: 14, weight: .regular)
    
    override class var supportsQuoting: Bool {
        true
    }
    
    let verifiedImage: UIImage?
    
    override init(message: MessageItem) {
        if message.sharedUserIsVerified ?? false {
            verifiedImage = R.image.ic_user_verified()
        } else if let id = message.sharedUserAppId, !id.isEmpty {
            verifiedImage = R.image.ic_user_bot()
        } else {
            verifiedImage = nil
        }
        super.init(message: message)
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        let fullnameWidth = ((message.sharedUserFullName ?? "") as NSString)
            .size(withAttributes: [NSAttributedString.Key.font: Self.fullnameFontSet.scaled])
            .width
        let iconWidth: CGFloat = {
            if let image = verifiedImage {
                return ContactMessageViewModel.titleSpacing + image.size.width
            } else {
                return 0
            }
        }()
        let idWidth = ((message.sharedUserIdentityNumber ?? "") as NSString)
            .size(withAttributes: [NSAttributedString.Key.font: Self.idFontSet.scaled])
            .width
        contentWidth = Self.leftViewSideLength
            + Self.spacing
            + ceil(max(fullnameWidth + iconWidth, idWidth))
        super.layout(width: width, style: style)
    }
    
}
