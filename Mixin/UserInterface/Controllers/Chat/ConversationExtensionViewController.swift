import UIKit

protocol ConversationExtensionViewController: class {
    var conversationViewController: ConversationViewController? { get }
}

extension ConversationExtensionViewController where Self: UIViewController {
    
    var conversationViewController: ConversationViewController? {
        return parent as? ConversationViewController
    }
    
}
