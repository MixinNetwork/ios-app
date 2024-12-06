import UIKit
import MixinServices

final class InConversationSearchViewController: SearchConversationViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchTextField.becomeFirstResponder()
    }
    
    override func pushConversation(viewController: ConversationViewController) {
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    func load(user: UserItem, conversationId: String) {
        self.conversationId = conversationId
        iconView.setImage(with: user)
    }
    
    func load(group: ConversationItem) {
        self.conversationId = group.conversationId
        self.conversation = conversation
        iconView.setGroupImage(with: group.iconUrl)
    }
    
}
