import UIKit
import MixinServices

class InConversationSearchViewController: SearchConversationViewController {
    
    override var navigationTitleLabel: UILabel? {
        get {
            return container?.titleLabel
        }
        set {
            
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchTextField.becomeFirstResponder()
    }
    
    override func prepareNavigationBar() {
        guard let container = container else {
            return
        }
        container.navigationBar.addSubview(iconView)
        iconView.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-20)
        }
    }
    
    override func pushConversation(viewController: ConversationViewController) {
        navigationController?.pushViewController(withBackRoot: viewController)
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
