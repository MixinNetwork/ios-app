import UIKit

protocol ConversationInputAccessible {
    var conversationInputViewController: ConversationInputViewController? { get }
}

extension ConversationInputAccessible where Self: UIViewController {
    
    var conversationInputViewController: ConversationInputViewController? {
        func findConversationInput(_ vc: UIViewController) -> ConversationInputViewController? {
            if let vc = vc as? ConversationInputViewController {
                return vc
            } else if let parent = vc.parent {
                return findConversationInput(parent)
            } else {
                return nil
            }
        }
        if let parent = parent {
            return findConversationInput(parent)
        } else {
            return nil
        }
    }
    
}
