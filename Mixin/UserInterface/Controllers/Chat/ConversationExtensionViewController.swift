import UIKit

protocol ConversationExtensionViewController: class {
    var canBeFullsized: Bool { get }
    var conversationViewController: ConversationViewController? { get }
}

extension ConversationExtensionViewController where Self: UIViewController {
    
    var conversationViewController: ConversationViewController? {
        return parent as? ConversationViewController
    }
    
}
