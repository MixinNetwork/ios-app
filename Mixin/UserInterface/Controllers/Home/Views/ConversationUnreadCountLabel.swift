import UIKit

class ConversationUnreadCountLabel: InsetLabel {
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
    
}
