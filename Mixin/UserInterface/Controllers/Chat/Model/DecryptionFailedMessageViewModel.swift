import UIKit

class DecryptionFailedMessageViewModel: TextMessageViewModel {
    
    override var rawContent: String {
        return Localized.CHAT_DECRYPTION_FAILED_HINT(username: message.userFullName)
            + Localized.CHAT_DECRYPTION_FAILED_LINK
    }
    
    override func linksMap(from attributedString: NSAttributedString) -> [NSRange : URL] {
        let location = (Localized.CHAT_DECRYPTION_FAILED_HINT(username: message.userFullName) as NSString).length
        let length = (Localized.CHAT_DECRYPTION_FAILED_LINK as NSString).length
        let range = NSRange(location: location, length: length)
        return [range: .aboutEncryption]
    }
    
}
