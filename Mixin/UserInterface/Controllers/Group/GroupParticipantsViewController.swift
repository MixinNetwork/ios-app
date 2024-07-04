import UIKit
import MixinServices

class GroupParticipantsViewController: UserItemPeerViewController<GroupParticipantCell> {
    
    private var myRole = ""
    private var conversation: ConversationItem!
    
    private lazy var responseHandler: (MixinAPI.Result<ConversationResponse>) -> Void = { result in
        if case let .failure(error) = result {
            showAutoHiddenHud(style: .error, text: error.localizedDescription)
        }
    }
    
    private var hasAdminPrivileges: Bool {
        return myRole == ParticipantRole.ADMIN.rawValue
            || myRole == ParticipantRole.OWNER.rawValue
    }
    
    private var showAdminActions: Bool {
        return models.count < maxGroupMemberCount && hasAdminPrivileges
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    class func instance(conversation: ConversationItem) -> UIViewController {
        let vc = GroupParticipantsViewController()
        vc.conversation = conversation
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.participants())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(participantDidChange(_:)), name: ParticipantDAO.participantDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(conversationDidChange(_:)), name: MixinServices.conversationDidChangeNotification, object: nil)
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
        searchBoxView.textField.resignFirstResponder()
        tableView.deselectRow(at: indexPath, animated: true)
        guard let cell = tableView.cellForRow(at: indexPath) as? GroupParticipantCell, !cell.activityIndicator.isAnimating else {
            return
        }
        let user = self.user(at: indexPath)
        guard user.userId != myUserId else {
            return
        }
        let alc = UIAlertController(title: nil, message: user.fullName, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: R.string.localizable.info(), style: .default, handler: { (action) in
            self.showInfo(user: user)
        }))
        alc.addAction(UIAlertAction(title: R.string.localizable.send_message(), style: .default, handler: { (action) in
            self.sendMessage(to: user)
        }))
        
        if myRole == ParticipantRole.OWNER.rawValue {
            if user.role.isEmpty {
                alc.addAction(UIAlertAction(title: R.string.localizable.make_group_admin(), style: .default, handler: { (action) in
                    self.makeAdmin(userId: user.userId)
                }))
            } else {
                alc.addAction(UIAlertAction(title: R.string.localizable.dismiss_as_admin(), style: .default, handler: { (action) in
                    self.dismissAdmin(userId: user.userId)
                }))
            }
        }
        if myRole == ParticipantRole.OWNER.rawValue || (user.role.isEmpty && !myRole.isEmpty) {
            alc.addAction(UIAlertAction(title: R.string.localizable.remove_from_group(), style: .destructive, handler: { (action) in
                self.remove(userId: user.userId)
            }))
        }
        alc.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        present(alc, animated: true, completion: nil)
    }
    
}

extension GroupParticipantsViewController {
    
    @objc func participantDidChange(_ notification: Notification) {
        guard let conversationId = notification.userInfo?[ParticipantDAO.UserInfoKey.conversationId] as? String else {
            return
        }
        guard conversationId == conversation.conversationId else {
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
        alc.addAction(UIAlertAction(title: R.string.localizable.add_participants(), style: .default, handler: { (_) in
            let id = self.conversation.conversationId
            let vc = AddMemberViewController.instance(appendingMembersToConversationId: id)
            self.navigationController?.pushViewController(vc, animated: true)
        }))
        alc.addAction(UIAlertAction(title: R.string.localizable.invite_to_group_via_link(), style: .default, handler: { (_) in
            let vc = InviteLinkViewController.instance(conversation: self.conversation)
            self.navigationController?.pushViewController(vc, animated: true)
        }))
        alc.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
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
                user.userId == myUserId
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
        let vc = UserProfileViewController(user: user)
        present(vc, animated: true, completion: nil)
    }
    
    private func sendMessage(to user: UserItem) {
        guard user.isCreatedByMessenger else {
            return
        }
        let vc = ConversationViewController.instance(ownerUser: user)
        navigationController?.pushViewController(withBackRoot: vc)
    }
    
    private func makeAdmin(userId: String) {
        cell(for: userId)?.startLoading()
        ConversationAPI.adminParticipant(conversationId: conversation.conversationId,
                                                userId: userId,
                                                completion: responseHandler)
    }

    private func dismissAdmin(userId: String) {
        cell(for: userId)?.startLoading()
        ConversationAPI.dismissAdminParticipant(conversationId: conversation.conversationId,
                                                userId: userId,
                                                completion: responseHandler)
    }
    
    private func remove(userId: String) {
        cell(for: userId)?.startLoading()
        ConversationAPI.removeParticipant(conversationId: conversation.conversationId,
                                                 userId: userId,
                                                 completion: responseHandler)
    }
    
    private func cell(for userId: String) -> GroupParticipantCell? {
        guard let indexPaths = tableView.indexPathsForVisibleRows else {
            return nil
        }
        guard let indexPath = indexPaths.first(where: { self.user(at: $0).userId == userId }) else {
            return nil
        }
        return tableView.cellForRow(at: indexPath) as? GroupParticipantCell
    }
    
}
