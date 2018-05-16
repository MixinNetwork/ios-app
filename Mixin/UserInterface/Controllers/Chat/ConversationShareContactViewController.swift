import UIKit

class ConversationShareContactViewController: ForwardViewController, MixinNavigationAnimating {

    private var conversationId: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func fetchData() {
        DispatchQueue.global().async { [weak self] in
            let contacts = UserDAO.shared.getForwardContacts()

            guard let weakSelf = self else {
                return
            }
            if contacts.count > 0 {
                weakSelf.sections.append(contacts)
            }
            DispatchQueue.main.async {
                weakSelf.tableView.reloadData()
            }
        }
    }

    override func forwardMessage(_ targetUser: ForwardUser) {
        var newMessage = Message.createMessage(category: MessageCategory.SIGNAL_CONTACT.rawValue, conversationId: conversationId, userId: AccountAPI.shared.accountUserId)
        newMessage.sharedUserId = targetUser.userId
        let transferData = TransferContactData(userId: targetUser.userId)
        newMessage.content = try! JSONEncoder().encode(transferData).base64EncodedString()

        let ownerUser = self.ownerUser
        DispatchQueue.global().async { [weak self] in
            SendMessageService.shared.sendMessage(message: newMessage, ownerUser: ownerUser, isGroupMessage: targetUser.isGroup)
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.navigationController?.popViewController(animated: true)
            }
        }
    }

    class func instance(ownerUser: UserItem?, conversationId: String) -> UIViewController {
        let vc = Storyboard.chat.instantiateViewController(withIdentifier: "share_contact") as! ConversationShareContactViewController
        vc.ownerUser = ownerUser
        vc.conversationId = conversationId
        return ContainerViewController.instance(viewController: vc, title: Localized.PROFILE_SHARE_CARD)
    }


}

extension ConversationShareContactViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }
}
