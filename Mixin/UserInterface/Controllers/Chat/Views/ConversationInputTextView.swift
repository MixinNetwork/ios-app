import UIKit

class ConversationInputTextView: UITextView {
    
    weak var overrideNext: UIResponder?

    override var next: UIResponder? {
        if let responder = overrideNext {
            return responder
        } else {
            return super.next
        }
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if overrideNext != nil {
            return false
        } else {
            return super.canPerformAction(action, withSender: sender)
        }
    }
    
}
