import UIKit

protocol ConversationAccessible {
    var conversationViewController: ConversationViewController? { get }
}

extension ConversationAccessible where Self: UIViewController {
    
    var conversationViewController: ConversationViewController? {
        func findConversation(_ vc: UIViewController) -> ConversationViewController? {
            if let vc = vc as? ConversationViewController {
                return vc
            } else if let parent = vc.parent {
                return findConversation(parent)
            } else {
                return nil
            }
        }
        if let parent = parent {
            return findConversation(parent)
        } else {
            return nil
        }
    }
    
    var composer: ConversationMessageComposer? {
        conversationViewController?.composer
    }
    
}
