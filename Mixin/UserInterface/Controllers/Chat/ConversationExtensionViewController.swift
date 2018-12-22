import UIKit

protocol ConversationExtensionViewController: class {
    var canBeFullsized: Bool { get }
    var conversationViewController: ConversationViewController? { get }
    func layoutForFullsized(_ fullsized: Bool)
}

extension ConversationExtensionViewController where Self: UIViewController {
    
    var conversationViewController: ConversationViewController? {
        return parent as? ConversationViewController
    }
    
    func layoutForFullsized(_ fullsized: Bool) {
        
    }
    
}
