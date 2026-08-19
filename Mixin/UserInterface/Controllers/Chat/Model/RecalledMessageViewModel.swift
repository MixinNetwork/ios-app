import UIKit
import MixinServices

class RecalledMessageViewModel: IconPrefixedTextMessageViewModel {
    
    override class var font: UIFont {
        MessageFontSet.recalledContent.scaled
    }
    
    override var rawContent: String {
        RecalledMessage.description(item: message)
    }
    
    override var showStatusImage: Bool {
        return false
    }
    
    override func layout(width: CGFloat, style: MessageViewModel.Style) {
        super.layout(width: width, style: style)
        if style.contains(.received) {
            prefixImage = R.image.ic_recalled_message_prefix_received()
        } else {
            prefixImage = R.image.ic_recalled_message_prefix_sent()
        }
    }
    
}
