import UIKit

class ContactSelectorViewController: UserItemPeerViewController<CheckmarkPeerCell>, MixinNavigationAnimating {
    
    private var ownerUser: UserItem?
    private var parentConversation: ConversationItem!
    private var selections = [String]()
    
    class func instance(ownerUser: UserItem?, conversation: ConversationItem) -> UIViewController {
        let vc = ContactSelectorViewController()
        vc.ownerUser = ownerUser
        vc.parentConversation = conversation
        return ContainerViewController.instance(viewController: vc, title: Localized.PROFILE_SHARE_CARD)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.allowsMultipleSelection = true
    }
    
    override func reloadTableViewSelections() {
        super.reloadTableViewSelections()
        var rows = [Int]()
        if isSearching {
            for (row, result) in searchResults.enumerated() {
                guard case let .contact(user) = result.target else {
                    continue
                }
                guard selections.contains(user.userId) else {
                    continue
                }
                rows.append(row)
            }
        } else {
            for (row, user) in models.enumerated() where selections.contains(user.userId) {
                rows.append(row)
            }
        }
        for row in rows {
            let indexPath = IndexPath(row: row, section: 0)
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let userId = user(at: indexPath)?.userId else {
            return
        }
        selections.append(userId)
        container?.rightButton.isEnabled = true
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard let userId = user(at: indexPath)?.userId else {
            return
        }
        if let idx = selections.index(of: userId) {
            selections.remove(at: idx)
        }
        if tableView.indexPathForSelectedRow == nil {
            container?.rightButton.isEnabled = false
        }
    }
    
}

extension ContactSelectorViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        guard let indexPaths = tableView.indexPathsForSelectedRows else {
            return
        }
        let userIds = indexPaths.map { models[$0.row].userId }
        let ownerUser = self.ownerUser
        let parentConversation = self.parentConversation!
        DispatchQueue.global().async { [weak self] in
            for userId in userIds {
                var message = Message.createMessage(category: MessageCategory.SIGNAL_CONTACT.rawValue,
                                                    conversationId: parentConversation.conversationId,
                                                    userId: AccountAPI.shared.accountUserId)
                message.sharedUserId = userId
                let transferData = TransferContactData(userId: userId)
                message.content = try! JSONEncoder().encode(transferData).base64EncodedString()
                SendMessageService.shared.sendMessage(message: message,
                                                      ownerUser: ownerUser,
                                                      isGroupMessage: parentConversation.isGroup())
            }
            DispatchQueue.main.async {
                self?.navigationController?.popViewController(animated: true)
            }
        }
    }
    
    func textBarRightButton() -> String? {
        return R.string.localizable.action_send()
    }
    
}
