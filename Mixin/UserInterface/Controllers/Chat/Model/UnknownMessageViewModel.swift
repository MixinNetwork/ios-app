import UIKit
import MixinServices

class UnknownMessageViewModel: TextMessageViewModel {
    
    override class var bubbleImageSet: BubbleImageSet.Type {
        return UnknownBubbleImageSet.self
    }
    
    override class var textColor: UIColor {
        return .white
    }
    
    override var rawContent: String {
        return Localized.CHAT_CELL_TITLE_UNKNOWN_CATEGORY
    }
    
    override init(message: MessageItem) {
        super.init(message: message)
        statusImage = nil
    }
    
}
