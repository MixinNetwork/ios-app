import UIKit

class GroupParticipantsViewController: UserItemPeerViewController<GroupParticipantCell> {
    
    private var myRole = ""
    private var conversation: ConversationItem!
    private var reloadParticipantsOperation: BlockOperation!
    
    private lazy var userWindow = UserWindow.instance()
    
    private var hasAdminPrivileges: Bool {
        return myRole == ParticipantRole.ADMIN.rawValue
            || myRole == ParticipantRole.OWNER.rawValue
    }
    
    private var showAdminActions: Bool {
        return models.count < 256 && hasAdminPrivileges
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    class func instance(conversation: ConversationItem) -> UIViewController {
        let vc = GroupParticipantsViewController()
        vc.conversation = conversation
        return ContainerViewController.instance(viewController: vc, title: Localized.GROUP_MENU_PARTICIPANTS)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(participantDidChange(_:)), name: .ParticipantDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(conversationDidChange(_:)), name: .ConversationDidChange, object: nil)
        let job = RefreshConversationJob(conversationId: conversation.conversationId)
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
    override func initData() {
        let op = ReloadParticipantsOperation(viewController: self)
        queue.addOperation(op)
    }
    
    override func search(keyword: String) {
        queue.operations
            .filter({ $0 is SearchOperation })
            .forEach({ $0.cancel() })
        let op = SearchOperation(viewController: self, keyword: keyword)
        queue.addOperation(op)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let user = user(at: indexPath), user.userId != AccountAPI.shared.accountUserId else {
            return
        }
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.GROUP_PARTICIPANT_MENU_INFO, style: .default, handler: { (action) in
            self.showInfo(user: user)
        }))
        alc.addAction(UIAlertAction(title: Localized.GROUP_PARTICIPANT_MENU_SEND, style: .default, handler: { (action) in
            self.sendMessage(to: user)
        }))
        
        if myRole == ParticipantRole.OWNER.rawValue && user.role.isEmpty {
            alc.addAction(UIAlertAction(title: Localized.GROUP_PARTICIPANT_MENU_ADMIN, style: .default, handler: { (action) in
                self.makeAdmin(user: user, indexPath: indexPath)
            }))
        }
        if !myRole.isEmpty {
            alc.addAction(UIAlertAction(title: Localized.GROUP_PARTICIPANT_MENU_REMOVE, style: .destructive, handler: { (action) in
                self.remove(user: user, indexPath: indexPath)
            }))
        }
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        present(alc, animated: true, completion: nil)
    }
    
}

extension GroupParticipantsViewController {
    
    @objc func participantDidChange(_ notification: Notification) {
        guard let conversationId = notification.object as? String, conversationId == conversation.conversationId else {
            return
        }
        queue.operations
            .filter({ $0 is ReloadParticipantsOperation })
            .forEach({ $0.cancel() })
        let op = ReloadParticipantsOperation(viewController: self)
        queue.addOperation(op)
    }
    
    @objc func conversationDidChange(_ sender: Notification) {
        guard let change = sender.object as? ConversationChange, change.conversationId == conversation.conversationId else {
            return
        }
        switch change.action {
        case let .updateConversation(conversation):
            self.conversation.codeUrl = conversation.codeUrl
        default:
            break
        }
    }
    
}

extension GroupParticipantsViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        guard showAdminActions else {
            return
        }
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.GROUP_NAVIGATION_TITLE_ADD_MEMBER, style: .default, handler: { (_) in
            let id = self.conversation.conversationId
            let vc = AddMemberViewController.instance(appendingMembersToConversationId: id)
            self.navigationController?.pushViewController(vc, animated: true)
        }))
        alc.addAction(UIAlertAction(title: Localized.GROUP_NAVIGATION_TITLE_INVITE_LINK, style: .default, handler: { (_) in
            let vc = InviteLinkViewController.instance(conversation: self.conversation)
            self.navigationController?.pushViewController(vc, animated: true)
        }))
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        present(alc, animated: true, completion: nil)
    }
    
    func imageBarRightButton() -> UIImage? {
        return showAdminActions ? R.image.ic_title_add() : nil
    }
    
}

extension GroupParticipantsViewController {
    
    class ReloadParticipantsOperation: Operation {
        
        weak var viewController: GroupParticipantsViewController?
        
        let conversationId: String
        
        init(viewController: GroupParticipantsViewController) {
            self.viewController = viewController
            self.conversationId = viewController.conversation.conversationId
        }
        
        override func main() {
            guard !isCancelled else {
                return
            }
            let participants = ParticipantDAO.shared.getParticipants(conversationId: conversationId)
            let me = participants.first(where: { (user) -> Bool in
                user.userId == AccountAPI.shared.accountUserId
            })
            DispatchQueue.main.sync {
                guard !isCancelled, let viewController = viewController else {
                    return
                }
                viewController.models = participants
                viewController.myRole = me?.role ?? ""
                viewController.container?.reloadRightButton()
                if let keyword = viewController.searchingKeyword {
                    viewController.search(keyword: keyword)
                } else {
                    viewController.tableView.reloadData()
                }
            }
        }
        
    }
    
    private func showInfo(user: UserItem) {
        userWindow.updateUser(user: user).presentView()
    }
    
    private func sendMessage(to user: UserItem) {
        let vc = ConversationViewController.instance(ownerUser: user)
        navigationController?.pushViewController(withBackRoot: vc)
    }
    
    private func makeAdmin(user: UserItem, indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as? GroupParticipantCell
        cell?.startLoading()
        ConversationAPI.shared.adminParticipant(conversationId: conversation.conversationId, userId: user.userId) { [weak cell] (result) in
            switch result {
            case .success:
                break
            case let .failure(error):
                showHud(style: .error, text: error.localizedDescription)
                cell?.stopLoading() // It's ok to stop cell's loading even if it has been reused
            }
        }
    }
    
    private func remove(user: UserItem, indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) as? GroupParticipantCell {
            cell.startLoading()
        }
        ConversationAPI.shared.removeParticipant(conversationId: conversation.conversationId, userId: user.userId) { (result) in
            switch result {
            case .success:
                break
            case let .failure(error):
                showHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
}
