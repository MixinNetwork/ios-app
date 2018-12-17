import UIKit

class CallConversationExtensionViewController: UIViewController, ConversationExtensionViewController {
    
    static func instance() -> CallConversationExtensionViewController {
        return Storyboard.chat.instantiateViewController(withIdentifier: "extension_call") as! CallConversationExtensionViewController
    }
    
    @IBAction func callAction(_ sender: Any) {
        conversationViewController?.callAction()
    }
    
}
