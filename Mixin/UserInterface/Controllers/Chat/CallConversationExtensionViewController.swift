import UIKit

class CallConversationExtensionViewController: UIViewController, ConversationExtensionViewController {
    
    static func instance() -> CallConversationExtensionViewController {
        return Storyboard.chat.instantiateViewController(withIdentifier: "extension_call") as! CallConversationExtensionViewController
    }
    
    var canBeFullsized: Bool {
        return false
    }
    
    @IBAction func callAction(_ sender: Any) {
        conversationViewController?.callAction()
    }
    
}
