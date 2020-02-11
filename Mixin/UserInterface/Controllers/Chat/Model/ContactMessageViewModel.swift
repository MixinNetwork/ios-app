import UIKit
import MixinServices

class ContactMessageViewModel: CardMessageViewModel {
    
    static let fullnameFont = UIFont.preferredFont(forTextStyle: .body)
    static let idFont = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
    
    override class var supportsQuoting: Bool {
        true
    }
    
    let verifiedImage: UIImage?
    
    override var contentWidth: CGFloat {
        calculatedContentWidth
    }
    
    private var calculatedContentWidth: CGFloat = 0
    
    override init(message: MessageItem) {
        if message.sharedUserIsVerified {
            verifiedImage = R.image.ic_user_verified()
        } else if !message.sharedUserAppId.isEmpty {
            verifiedImage = R.image.ic_user_bot()
        } else {
            verifiedImage = nil
        }
        super.init(message: message)
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        let fullnameWidth = (message.sharedUserFullName as NSString)
            .size(withAttributes: [NSAttributedString.Key.font: Self.fullnameFont])
            .width
        let iconWidth: CGFloat
        if let image = verifiedImage {
            iconWidth = ContactMessageCell.titleSpacing + image.size.width
        } else {
            iconWidth = 0
        }
        let idWidth = (message.sharedUserIdentityNumber as NSString)
            .size(withAttributes: [NSAttributedString.Key.font: Self.idFont])
            .width
        calculatedContentWidth = ceil(max(fullnameWidth + iconWidth, idWidth))
            + 40 + 12 + receivedLeadingMargin + receivedTrailingMargin
        calculatedContentWidth = max(160, min(260, calculatedContentWidth))
        super.layout(width: width, style: style)
    }
    
}
