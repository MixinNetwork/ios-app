import UIKit

class GroupInfoViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    private let titleCellReuseId = "GroupTitle"
    private let announcementCellReuseId = "GroupAnnouncement"
    private let notificationCellReuseId = "GroupNotification"
    private let addMemberCellReuseId = "AddMember"
    private let inviteLinkCellReuseId = "InviteLink"
    private let memberCellReuseId = "GroupMember"
    
    private var titleCell: GroupTitleCell!
    private var announcementCell: GroupAnnouncementCell!
    private var notificationSwitchCell: GroupNotificationCell!
    private var addMemberCell: UITableViewCell!
    private var inviteLinkCell: UITableViewCell!
    private var rightButton: StateResponsiveButton?
    
    private var currentAccountRole = ""
    private var conversation: ConversationItem!
    private var participants = [UserItem]()
    private var initialAnnouncementMode = CollapsingTextView.Mode.collapsed
    private var blinkAnnouncement = false
    private lazy var userWindow = UserWindow.instance()
    
    private var newName: String {
        return changeNameController.textFields?.first?.text ?? ""
    }
    private var hasAdminPrivileges: Bool {
        return currentAccountRole == ParticipantRole.ADMIN.rawValue
            || currentAccountRole == ParticipantRole.OWNER.rawValue
    }
    private var showAdminActions: Bool {
        return participants.count < 256 && hasAdminPrivileges
    }
    private var muteRequestInProgress = false {
        didSet {
            if muteRequestInProgress {
                notificationSwitchCell.muteDetailLabel.isHidden = true
                notificationSwitchCell.mutingIndicator.startAnimating()
            } else {
                notificationSwitchCell.muteDetailLabel.isHidden = false
                notificationSwitchCell.mutingIndicator.stopAnimating()
            }
        }
    }
    
    private lazy var changeNameController: UIAlertController = {
        let vc = alertInput(title: Localized.CONTACT_TITLE_CHANGE_NAME, placeholder: Localized.PLACEHOLDER_NEW_NAME, handler: { [weak self] (_) in
            self?.changeName()
        })
        vc.textFields?.first?.addTarget(self, action: #selector(checkNewNameAction(_:)), for: .editingChanged)
        vc.actions[1].isEnabled = false
        return vc
    }()
    private lazy var muteDurationController: UIAlertController = {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let conversationId = conversation.conversationId
        alert.addAction(UIAlertAction(title: Localized.PROFILE_MUTE_DURATION_8H, style: .default, handler: { [weak self] (alert) in
            self?.muteGroupAction(muteIntervalInSeconds: muteDuration8H)
        }))
        alert.addAction(UIAlertAction(title: Localized.PROFILE_MUTE_DURATION_1WEEK, style: .default, handler: { [weak self] (alert) in
            self?.muteGroupAction(muteIntervalInSeconds: muteDuration1Week)
        }))
        alert.addAction(UIAlertAction(title: Localized.PROFILE_MUTE_DURATION_1YEAR, style: .default, handler: { [weak self] (alert) in
            self?.muteGroupAction(muteIntervalInSeconds: muteDuration1Year)
        }))
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        return alert
    }()
    private lazy var unmuteController: UIAlertController = {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let conversationId = conversation.conversationId
        alert.addAction(UIAlertAction(title: Localized.PROFILE_UNMUTE, style: .default, handler: { [weak self] (alert) in
            self?.muteGroupAction(muteIntervalInSeconds: 0)
        }))
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        return alert
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        fetchParticipants()
        prepareTableView()
        NotificationCenter.default.addObserver(self, selector: #selector(participantDidChange(_:)), name: .ParticipantDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(conversationDidChange(_:)), name: .ConversationDidChange, object: nil)
        ConcurrentJobQueue.shared.addJob(job: RefreshConversationJob(conversationId: conversation.conversationId))
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func editGroupNameAction() {
        changeNameController.textFields?[0].text = conversation.name
        present(changeNameController, animated: true, completion: nil)
    }
    
    @objc func checkNewNameAction(_ sender: Any) {
        changeNameController.actions[1].isEnabled = !newName.isEmpty && newName.count <= 25
    }
    
    @objc func participantDidChange(_ notification: Notification) {
        guard let conversationId = notification.object as? String, conversationId == conversation.conversationId else {
            return
        }
        fetchParticipants()
    }
    
    @objc func conversationDidChange(_ notification: Notification) {
        guard let change = notification.object as? ConversationChange, change.conversationId == conversation.conversationId else {
            return
        }
        switch change.action {
        case let .updateConversation(response):
            conversation.codeUrl = response.codeUrl
            conversation.name = response.name
            conversation.announcement = response.announcement
            titleCell.render(conversation: conversation)
            announcementCell.render(announcement: conversation.announcement, showDisclosureIndicator: hasAdminPrivileges)
            if (navigationController?.topViewController as? ContainerViewController)?.viewController != self {
                announcementCell.textView.mode = .collapsed
            }
            let selectedIndexPath = tableView.indexPathForSelectedRow
            tableView.reloadData()
            if let indexPath = selectedIndexPath {
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        case let .updateGroupIcon(iconUrl):
            conversation.iconUrl = iconUrl
            titleCell.render(conversation: conversation)
        default:
            break
        }
    }
    
    class func instance(conversation: ConversationItem, initialAnnouncementMode: CollapsingTextView.Mode = .collapsed, blinkAnnouncement: Bool = false) -> UIViewController {
        let vc = Storyboard.group.instantiateViewController(withIdentifier: "group_info") as! GroupInfoViewController
        vc.conversation = conversation
        vc.initialAnnouncementMode = initialAnnouncementMode
        vc.blinkAnnouncement = blinkAnnouncement
        return ContainerViewController.instance(viewController: vc, title: Localized.GROUP_NAVIGATION_TITLE_GROUP_INFO)
    }
    
}

// MARK: - ContainerViewControllerDelegate
extension GroupInfoViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.GROUP_MENU_CLEAR, style: .destructive, handler: { [weak self] (action) in
            self?.clearChatAction()
        }))
        alc.addAction(UIAlertAction(title: Localized.GROUP_MENU_EXIT, style: .destructive, handler: { [weak self] (action) in
            self?.exitGroupAction()
        }))
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        self.present(alc, animated: true, completion: nil)
    }
    
    func imageBarRightButton() -> UIImage? {
        return #imageLiteral(resourceName: "ic_titlebar_more")
    }
    
    func prepareBar(rightButton: StateResponsiveButton) {
        self.rightButton = rightButton
    }
    
}

// MARK: - UITableViewDataSource
extension GroupInfoViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            let showAnnouncement = !conversation.announcement.isEmpty || hasAdminPrivileges
            return showAnnouncement ? 2 : 1
        case 1:
            return 1
        default:
            return showAdminActions ? participants.count + 2 : participants.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            if indexPath.row == 0 {
                return titleCell
            } else {
                return announcementCell
            }
        case 1:
            return notificationSwitchCell
        default:
            let showAdminActions = self.showAdminActions
            if showAdminActions && indexPath.row == 0 {
                return addMemberCell
            } else if showAdminActions && indexPath.row == 1 {
                return inviteLinkCell
            } else {
                let idx = showAdminActions ? indexPath.row - 2 : indexPath.row
                let participant = participants[idx]
                let cell = tableView.dequeueReusableCell(withIdentifier: memberCellReuseId) as! GroupMemberCell
                cell.render(user: participant)
                return cell
            }
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 2 ? Localized.GROUP_SECTION_TITLE_MEMBERS(count: participants.count) : nil
    }
    
}

// MARK: - UITableViewDelegate
extension GroupInfoViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if cell == announcementCell, blinkAnnouncement {
            blinkAnnouncement = false
            CATransaction.perform(blockWithTransaction: {
                tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            }, completion: {
                self.tableView.deselectRow(at: indexPath, animated: true)
            })
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? CGFloat.leastNormalMagnitude : 20
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return section == 0 ? 10 : 20
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            if indexPath.row == 1 {
                return announcementCell.height
            } else {
                return 76
            }
        case 1:
            return 44
        default:
            return 60
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            if indexPath.row == 1 && hasAdminPrivileges {
                let vc = GroupAnnouncementViewController.instance(conversation: conversation)
                navigationController?.pushViewController(vc, animated: true)
            }
        case 1:
            if !muteRequestInProgress {
                let controller = conversation.isMuted ? unmuteController : muteDurationController
                present(controller, animated: true, completion: nil)
            }
        default:
            let showAdminActions = self.showAdminActions
            if showAdminActions && indexPath.row == 0 {
                navigationController?.pushViewController(AddMemberViewController.instance(conversationId: conversation.conversationId), animated: true)
            } else if showAdminActions && indexPath.row == 1 {
                navigationController?.pushViewController(InviteLinkViewController.instance(conversation: conversation), animated: true)
            } else {
                let idx = showAdminActions ? indexPath.row - 2 : indexPath.row
                let participant = participants[idx]
                guard participant.userId != AccountAPI.shared.accountUserId else {
                    return
                }

                userWindow.updateUser(user: participant).presentPopupControllerAnimated()
                
                let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                alc.addAction(UIAlertAction(title: Localized.GROUP_PARTICIPANT_MENU_INFO, style: .default, handler: { [weak self] (action) in
                    self?.infoAction(participant: participant)
                }))
                alc.addAction(UIAlertAction(title: Localized.GROUP_PARTICIPANT_MENU_SEND, style: .default, handler: { [weak self] (action) in
                    self?.sendMessageAction(participant: participant)
                }))
                
                if currentAccountRole == ParticipantRole.OWNER.rawValue {
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
    }
    
}

// MARK: - CollapsingTextViewDelegate
extension GroupInfoViewController: CollapsingTextViewDelegate {
    
    func collapsingTextView(_ textView: CollapsingTextView, didChangeModeTo mode: CollapsingTextView.Mode) {
        tableView.beginUpdates()
        tableView.endUpdates()
    }
    
}

// MARK: - Private works
extension GroupInfoViewController {
    
    private func prepareTableView() {
        tableView.register(UINib(nibName: "GroupMemberCell", bundle: .main), forCellReuseIdentifier: memberCellReuseId)
        titleCell = tableView.dequeueReusableCell(withIdentifier: titleCellReuseId) as! GroupTitleCell
        titleCell.editButton.addTarget(self, action: #selector(editGroupNameAction), for: .touchUpInside)
        titleCell.render(conversation: conversation)
        announcementCell = tableView.dequeueReusableCell(withIdentifier: announcementCellReuseId) as! GroupAnnouncementCell
        announcementCell.textView.collapsingTextViewDelegate = self
        announcementCell.textView.mode = initialAnnouncementMode
        announcementCell.render(announcement: conversation.announcement, showDisclosureIndicator: hasAdminPrivileges)
        notificationSwitchCell = tableView.dequeueReusableCell(withIdentifier: notificationCellReuseId) as! GroupNotificationCell
        notificationSwitchCell.render(conversation: conversation)
        addMemberCell = tableView.dequeueReusableCell(withIdentifier: addMemberCellReuseId)
        inviteLinkCell = tableView.dequeueReusableCell(withIdentifier: inviteLinkCellReuseId)
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
                    weakSelf.titleCell.editButton.isHidden = my.role.isEmpty
                    weakSelf.titleCell.placeView.isHidden = !my.role.isEmpty
                }
                weakSelf.announcementCell.render(announcement: weakSelf.conversation.announcement,
                                                 showDisclosureIndicator: weakSelf.hasAdminPrivileges)
                let selectedIndexPath = weakSelf.tableView.indexPathForSelectedRow
                weakSelf.tableView.reloadData()
                if let indexPath = selectedIndexPath {
                    weakSelf.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                }
            }
        }
    }
    
    private func changeName() {
        titleCell.editButton.isBusy = true
        ConversationAPI.shared.updateGroupName(conversationId: conversation.conversationId, name: newName) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.titleCell.editButton.isBusy = false
            switch result {
            case .success:
                weakSelf.conversation.name = weakSelf.newName
                weakSelf.titleCell.nameLabel.text = weakSelf.newName
            case let .failure(_, didHandled):
                guard !didHandled else {
                    return
                }
                NotificationCenter.default.postOnMain(name: .ErrorMessageDidAppear, object: Localized.TOAST_OPERATION_FAILED)
            }
        }
    }
    
    private func muteGroupAction(muteIntervalInSeconds: Int64) {
        muteRequestInProgress = true
        let conversationId = conversation.conversationId
        if muteIntervalInSeconds == 0 {
            conversation.muteUntil = Date().toUTCString()
            notificationSwitchCell.render(conversation: conversation)
        } else {
            conversation.muteUntil = Date(timeInterval: Double(muteIntervalInSeconds), since: Date()).toUTCString()
            notificationSwitchCell.render(conversation: conversation)
        }
        ConversationAPI.shared.mute(conversationId: conversationId, duration: muteIntervalInSeconds) { [weak self] (result) in
            switch result {
            case let .success(response):
                DispatchQueue.global().async {
                    ConversationDAO.shared.updateConversationMuteUntil(conversationId: conversationId, muteUntil: response.muteUntil)
                }
            case let .failure(_, didHandled):
                guard !didHandled else {
                    return
                }
                NotificationCenter.default.postOnMain(name: .ErrorMessageDidAppear, object: Localized.TOAST_OPERATION_FAILED)
            }
            self?.muteRequestInProgress = false
        }
    }
    
    private func clearChatAction() {
        guard let conversationId = conversation?.conversationId else {
            return
        }
        
        self.rightButton?.isBusy = true
        DispatchQueue.global().async { [weak self] in
            MessageDAO.shared.clearChat(conversationId: conversationId)
            NotificationCenter.default.postOnMain(name: .ToastMessageDidAppear, object: Localized.GROUP_CLEAR_SUCCESS)
            DispatchQueue.main.async {
                self?.rightButton?.isBusy = false
            }
        }
    }
    
    private func exitGroupAction() {
        guard let conversationId = conversation?.conversationId else {
            return
        }
        
        self.rightButton?.isBusy = true
        DispatchQueue.global().async { [weak self] in
            ConversationDAO.shared.makeQuitConversation(conversationId: conversationId)
            NotificationCenter.default.postOnMain(name: .ConversationDidChange, object: nil)
            DispatchQueue.main.async {
                self?.navigationController?.backToHome()
            }
        }
    }
    
    private func infoAction(participant: UserItem) {
        userWindow.updateUser(user: participant).presentPopupControllerAnimated()
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
            case let .failure(_, didHandled):
                cell.stopLoading()
                guard !didHandled else {
                    return
                }
                NotificationCenter.default.postOnMain(name: .ErrorMessageDidAppear, object: Localized.TOAST_OPERATION_FAILED)
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
            case let .failure(_, didHandled):
                guard !didHandled else {
                    return
                }
                NotificationCenter.default.postOnMain(name: .ErrorMessageDidAppear, object: Localized.TOAST_OPERATION_FAILED)
            }
        }
    }
    
}
