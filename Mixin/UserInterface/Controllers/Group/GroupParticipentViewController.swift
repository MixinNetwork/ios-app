import UIKit

class GroupParticipentViewController: UIViewController {

    @IBOutlet weak var searchBoxView: ModernSearchBoxView!
    @IBOutlet weak var tableView: UITableView!

    private let memberCellReuseId = "GroupMember"
    
    private var currentAccountRole = ""
    private var conversation: ConversationItem!
    private var participants = [UserItem]()
    private lazy var userWindow = UserWindow.instance()
    private var searchResult = [UserItem]()

    private var isSearching: Bool {
        return !(searchBoxView.textField.text ?? "").isEmpty
    }
    private var hasAdminPrivileges: Bool {
        return currentAccountRole == ParticipantRole.ADMIN.rawValue
            || currentAccountRole == ParticipantRole.OWNER.rawValue
    }
    private var showAdminActions: Bool {
        return participants.count < 256 && hasAdminPrivileges
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        fetchParticipants()
        prepareTableView()
        searchBoxView.textField.delegate = self
        searchBoxView.textField.addTarget(self, action: #selector(searchAction(_:)), for: .editingChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(participantDidChange(_:)), name: .ParticipantDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(conversationDidChange(_:)), name: .ConversationDidChange, object: nil)
        ConcurrentJobQueue.shared.addJob(job: RefreshConversationJob(conversationId: conversation.conversationId))
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @IBAction func searchAction(_ sender: Any) {
        let keyword = (searchBoxView.textField.text ?? "").uppercased()
        if keyword.isEmpty {
            searchResult = []
        } else {
            searchResult = participants.filter { $0.fullName.uppercased().contains(keyword) }
        }
        tableView.reloadData()
    }
    
    @objc func participantDidChange(_ notification: Notification) {
        guard let conversationId = notification.object as? String, conversationId == conversation.conversationId else {
            return
        }
        fetchParticipants()
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

    
    class func instance(conversation: ConversationItem) -> UIViewController {
        let vc = Storyboard.group.instantiateViewController(withIdentifier: "group_info") as! GroupParticipentViewController
        vc.conversation = conversation
        return ContainerViewController.instance(viewController: vc, title: Localized.GROUP_MENU_PARTICIPANTS)
    }
    
}

extension GroupParticipentViewController: ContainerViewControllerDelegate {

    func barRightButtonTappedAction() {
        guard showAdminActions else {
            return
        }
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.GROUP_NAVIGATION_TITLE_ADD_MEMBER, style: .default, handler: { [weak self](_) in
            guard let weakSelf = self else {
                return
            }
            let vc = AddMemberViewController.instance(appendMembersToExistedGroupOfConversationId: weakSelf.conversation.conversationId)
            weakSelf.navigationController?.pushViewController(vc, animated: true)
        }))
        alc.addAction(UIAlertAction(title: Localized.GROUP_NAVIGATION_TITLE_INVITE_LINK, style: .default, handler: { [weak self](_) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.navigationController?.pushViewController(InviteLinkViewController.instance(conversation: weakSelf.conversation), animated: true)
        }))
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        self.present(alc, animated: true, completion: nil)
    }

    func imageBarRightButton() -> UIImage? {
        return showAdminActions ? R.image.ic_title_add() : nil
    }

}

// MARK: - UITableViewDataSource
extension GroupParticipentViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isSearching {
            return searchResult.count
        } else {
            return participants.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        if isSearching {
            let participantCell = tableView.dequeueReusableCell(withIdentifier: memberCellReuseId) as! GroupMemberCell
            participantCell.render(user: searchResult[indexPath.row])
            cell = participantCell
        } else {
            let participantCell = tableView.dequeueReusableCell(withIdentifier: memberCellReuseId) as! GroupMemberCell
            participantCell.render(user: participants[indexPath.row])
            cell = participantCell
        }
        return cell
    }
    
}

// MARK: - UITableViewDelegate
extension GroupParticipentViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if isSearching {
            let participant = searchResult[indexPath.row]
            guard participant.userId != AccountAPI.shared.accountUserId else {
                return
            }
            showMenuAction(participant: participant, indexPath: indexPath)
        } else {
            if let cell = tableView.cellForRow(at: indexPath) as? GroupMemberCell, !cell.loadingView.isAnimating {
                let participant = participants[indexPath.row]
                guard participant.userId != AccountAPI.shared.accountUserId else {
                    return
                }
                showMenuAction(participant: participant, indexPath: indexPath)
            }
        }
    }

    private func showMenuAction(participant: UserItem, indexPath: IndexPath) {
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.GROUP_PARTICIPANT_MENU_INFO, style: .default, handler: { [weak self] (action) in
            self?.infoAction(participant: participant)
        }))
        alc.addAction(UIAlertAction(title: Localized.GROUP_PARTICIPANT_MENU_SEND, style: .default, handler: { [weak self] (action) in
            self?.sendMessageAction(participant: participant)
        }))

        if currentAccountRole == ParticipantRole.OWNER.rawValue && participant.role.isEmpty {
            alc.addAction(UIAlertAction(title: Localized.GROUP_PARTICIPANT_MENU_ADMIN, style: .default, handler: { [weak self] (action) in
                self?.makeAdminAction(participant: participant, indexPath: indexPath)
            }))
        }
        if !currentAccountRole.isEmpty {
            alc.addAction(UIAlertAction(title: Localized.GROUP_PARTICIPANT_MENU_REMOVE, style: .destructive, handler: { [weak self] (action) in
                self?.removeParticipantAction(participant: participant, indexPath: indexPath)
            }))
        }
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        self.present(alc, animated: true, completion: nil)
    }
    
}

// MARK: - Private works
extension GroupParticipentViewController {
    
    private func prepareTableView() {
        tableView.register(UINib(nibName: "GroupMemberCell", bundle: .main), forCellReuseIdentifier: memberCellReuseId)
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
    }
    
    private func fetchParticipants() {
        guard let conversationId = conversation?.conversationId else {
            return
        }
        DispatchQueue.global().async { [weak self] in
            let participants = ParticipantDAO.shared.getParticipants(conversationId: conversationId)
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.participants = participants
                if let my = participants.first(where: { (user) -> Bool in
                    return user.userId == AccountAPI.shared.accountUserId
                }) {
                    weakSelf.currentAccountRole = my.role
                    weakSelf.container?.reloadRightButton()
                }
                weakSelf.searchAction(weakSelf.searchBoxView.textField)
                if weakSelf.searchResult.count == 0 {
                    weakSelf.searchBoxView.textField.text = ""
                    weakSelf.view.endEditing(true)
                    weakSelf.tableView.reloadData()
                }
            }
        }
    }

    private func infoAction(participant: UserItem) {
        userWindow.updateUser(user: participant).presentView()
    }
    
    private func sendMessageAction(participant: UserItem) {
        navigationController?.pushViewController(withBackRoot: ConversationViewController.instance(ownerUser: participant))
    }
    
    private func makeAdminAction(participant: UserItem, indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? GroupMemberCell else {
            return
        }
        cell.startLoading()
        ConversationAPI.shared.adminParticipant(conversationId: conversation.conversationId, userId: participant.userId) { [weak self] (result) in
            guard self != nil else {
                return
            }
            switch result {
            case .success:
                break
            case let .failure(error):
                UIApplication.showHud(style: .error, text: error.localizedDescription)
                cell.stopLoading()
            }
        }
    }
    
    private func removeParticipantAction(participant: UserItem, indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? GroupMemberCell else {
            return
        }
        cell.startLoading()
        ConversationAPI.shared.removeParticipant(conversationId: conversation.conversationId, userId: participant.userId) { (result) in
            switch result {
            case .success:
                break
            case let .failure(error):
                UIApplication.showHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
}

extension GroupParticipentViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        searchBoxView.textField.text = nil
        searchBoxView.textField.resignFirstResponder()
        tableView.reloadData()
        return false
    }

}
