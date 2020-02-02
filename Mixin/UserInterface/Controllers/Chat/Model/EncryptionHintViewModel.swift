import UIKit
import MixinServices

class EncryptionHintViewModel: SystemMessageViewModel {
    
    override init(message: MessageItem) {
        super.init(message: message)
        backgroundImage = R.image.ic_chat_bubble_encryption()
    }
    
}
