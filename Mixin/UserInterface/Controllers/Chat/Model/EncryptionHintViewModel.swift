import UIKit
import MixinServices

class EncryptionHintViewModel: SystemMessageViewModel {
    
    init(message: MessageItem) {
        super.init(message: message, text: message.content ?? "")
        backgroundImage = R.image.ic_chat_bubble_encryption()
    }
    
}
