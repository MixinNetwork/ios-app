import UIKit

class DecryptionFailedMessageViewModel: TextMessageViewModel {
    
    override var fixedLinks: [NSRange : URL]? {
        let range = NSRange(location: (Localized.CHAT_DECRYPTION_FAILED_HINT(username: message.userFullName) as NSString).length,
                            length: (Localized.CHAT_DECRYPTION_FAILED_LINK as NSString).length)
        return [range: .aboutEncryption]
    }
    
    override init(message: MessageItem, style: Style, fits layoutWidth: CGFloat) {
        message.content = Localized.CHAT_DECRYPTION_FAILED_HINT(username: message.userFullName) + Localized.CHAT_DECRYPTION_FAILED_LINK
        super.init(message: message, style: style, fits: layoutWidth)
    }
    
}
