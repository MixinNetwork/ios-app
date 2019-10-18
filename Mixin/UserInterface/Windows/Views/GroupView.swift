import UIKit
import Alamofire

class GroupView: CornerView {
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var groupMembersLabel: UILabel!
    @IBOutlet weak var announcementScrollView: UIScrollView!
    @IBOutlet weak var announcementLabel: CollapsingLabel!
    @IBOutlet weak var viewButton: StateResponsiveButton!
    @IBOutlet weak var moreButton: StateResponsiveButton!
    @IBOutlet weak var inGroupActionsView: UIView!
    @IBOutlet weak var joinButton: BusyButton!
    
    @IBOutlet weak var showJoinGroupConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideJoinGroupConstraint: NSLayoutConstraint!
    @IBOutlet weak var showInGroupActionsConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideInGroupActionsConstraint: NSLayoutConstraint!
    @IBOutlet weak var announcementScrollViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var announcementScrollViewHeightConstraint: NSLayoutConstraint!
    
    private weak var superView: BottomSheetView?
    private var conversation: ConversationItem!
    private var conversationResponse: ConversationResponse!
    private var codeId: String?
    private var initialAnnouncementMode = CollapsingLabel.Mode.collapsed
    private var isAdmin = false
    
    private lazy var changeNameController: UIAlertController = {
        let vc = UIApplication.currentActivity()!.alertInput(title: Localized.CONTACT_TITLE_CHANGE_NAME, placeholder: Localized.PLACEHOLDER_NEW_NAME, handler: { [weak self] (_) in
            self?.changeNameAction()
        })
        vc.textFields?.first?.addTarget(self, action: #selector(checkNewNameAction(_:)), for: .editingChanged)
        vc.actions[1].isEnabled = false
        return vc
    }()
    private var newName: String {
        return changeNameController.textFields?.first?.text ?? ""
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        announcementLabel.delegate = self
    }
    
    func render(codeId: String, conversation: ConversationResponse, ownerUser: UserItem, participants: [ParticipantUser], alreadyInTheGroup: Bool, superView: BottomSheetView) {
        self.superView = superView
        self.conversation = ConversationItem(response: conversation)
        self.conversationResponse = conversation
        self.codeId = codeId

        renderConversation(alreadyInTheGroup: alreadyInTheGroup)
        renderParticipants(count: conversation.participants.count)
    }

    func render(conversation: ConversationItem, superView: BottomSheetView, initialAnnouncementMode: CollapsingLabel.Mode) {
        self.superView = superView
        self.conversation = conversation
        self.initialAnnouncementMode = initialAnnouncementMode

        renderConversation(alreadyInTheGroup: true)

        let conversationId = conversation.conversationId
        DispatchQueue.global().async { [weak self] in
            let participantCount = ParticipantDAO.shared.getParticipantCount(conversationId: conversationId)
            self?.isAdmin = ParticipantDAO.shared.isAdmin(conversationId: conversationId, userId: AccountAPI.shared.accountUserId)
            DispatchQueue.main.async {
                self?.renderParticipants(count: participantCount)
            }
        }
    }

    private func renderConversation(alreadyInTheGroup: Bool) {
        inGroupActionsView.isHidden = !alreadyInTheGroup
        joinButton.isHidden = alreadyInTheGroup
        if alreadyInTheGroup {
            showJoinGroupConstraint.priority = .defaultLow
            hideJoinGroupConstraint.priority = .defaultHigh
            showInGroupActionsConstraint.priority = .defaultHigh
            hideInGroupActionsConstraint.priority = .defaultLow
        } else {
            showJoinGroupConstraint.priority = .defaultHigh
            hideJoinGroupConstraint.priority = .defaultLow
            showInGroupActionsConstraint.priority = .defaultLow
            hideInGroupActionsConstraint.priority = .defaultHigh
        }
        moreButton.isHidden = !alreadyInTheGroup
        viewButton.isHidden = !alreadyInTheGroup
        if conversation.iconUrl.isEmpty {
            loadGroupIcon()
        } else {
            avatarImageView.setGroupImage(with: conversation.iconUrl)
        }
        nameLabel.text = conversation.name
        announcementLabel.text = conversation.announcement
        announcementLabel.mode = initialAnnouncementMode
        announcementLabel.isHidden = conversation.announcement.isEmpty
        if conversation.announcement.isEmpty {
            showJoinGroupConstraint.constant = 0
            announcementScrollViewHeightConstraint.constant = 0
            announcementScrollViewTopConstraint.constant = 7
        } else {
            showJoinGroupConstraint.constant = 12
            announcementScrollViewHeightConstraint.constant = announcementLabel.intrinsicContentSize.height
            announcementScrollViewTopConstraint.constant = 14
        }
    }

    private func loadGroupIcon() {
        avatarImageView.image = R.image.ic_conversation_group()
        
        let conversationId = conversation.conversationId
        let conversationResponse = self.conversationResponse

        DispatchQueue.global().async { [weak self] in
            func makeGroupIcon(participants: [ParticipantUser]) {
                let groupImage = GroupIconMaker.make(participants: participants) ?? R.image.ic_conversation_group()
                DispatchQueue.main.async {
                    self?.avatarImageView.image = groupImage
                }
            }

            if let participants = conversationResponse?.participants {
                let participantIds = participants.prefix(4).map { $0.userId }
                switch UserAPI.shared.showUsers(userIds: participantIds) {
                case let .success(users):
                    let participants = users.map { ParticipantUser(conversationId: conversationId, role: "", userId: $0.userId, userFullName: $0.fullName, userAvatarUrl: $0.avatarUrl, userIdentityNumber: $0.identityNumber) }
                    makeGroupIcon(participants: participants)
                case let .failure(error):
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            } else {
                let participants = ParticipantDAO.shared.getGroupIconParticipants(conversationId: conversationId)
                makeGroupIcon(participants: participants)
            }
        }
    }
    
    private func renderParticipants(count: Int) {
        groupMembersLabel.text = Localized.GROUP_TITLE_MEMBERS(count: "\(count)")
    }
    
    @IBAction func moreAction(_ sender: Any) {
        superView?.dismissPopupControllerAnimated()
        let alc = UIAlertController(title: conversation.name, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.GROUP_MENU_PARTICIPANTS, style: .default, handler: { (action) in
            self.showParticipantsAction(alc)
        }))
        alc.addAction(UIAlertAction(title: R.string.localizable.profile_search_conversation(), style: .default, handler: { (action) in
            self.searchConversationAction()
        }))
        alc.addAction(UIAlertAction(title: R.string.localizable.chat_shared_media(), style: .default, handler: { (action) in
            self.showSharedMediaAction()
        }))
        if isAdmin {
            alc.addAction(UIAlertAction(title: Localized.GROUP_MENU_ANNOUNCEMENT, style: .default, handler: { (action) in
                self.editAnnouncementAction()
            }))
            alc.addAction(UIAlertAction(title: Localized.PROFILE_EDIT_NAME, style: .default, handler: { (action) in
                self.editGroupNameAction()
            }))
        }
        if conversation.isMuted {
            alc.addAction(UIAlertAction(title: Localized.PROFILE_UNMUTE, style: .default, handler: { (action) in
                self.unmuteAction()
            }))
        } else {
            alc.addAction(UIAlertAction(title: Localized.PROFILE_MUTE, style: .default, handler: { (action) in
                self.muteAction()
            }))
        }
        alc.addAction(UIAlertAction(title: Localized.GROUP_MENU_CLEAR, style: .destructive, handler: { (action) in
            self.clearChatAction()
        }))
        alc.addAction(UIAlertAction(title: Localized.GROUP_MENU_EXIT, style: .destructive, handler: { (action) in
            self.exitGroupAction()
        }))

        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        UIApplication.currentActivity()?.present(alc, animated: true, completion: nil)
    }

    @IBAction func viewAction(_ sender: Any) {
        guard conversationResponse != nil else {
            superView?.dismissPopupControllerAnimated()
            return
        }
        guard !viewButton.isBusy else {
            return
        }
        viewButton.isBusy = true
        saveConversation(conversation: conversationResponse)
    }
    

    @IBAction func joinAction(_ sender: Any) {
        guard !joinButton.isBusy, let codeId = self.codeId, !codeId.isEmpty else {
            return
        }
        joinButton.isBusy = true
        ConversationAPI.shared.joinConversation(codeId: codeId) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case .success(let response):
                weakSelf.saveConversation(conversation: response)
            case let .failure(error):
                weakSelf.joinButton.isBusy = false
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        superView?.dismissPopupControllerAnimated()
    }
    
    @IBAction func showParticipantsAction(_ sender: Any) {
        superView?.dismissPopupControllerAnimated()
        let vc = GroupParticipantsViewController.instance(conversation: conversation)
        UIApplication.homeNavigationController?.pushViewController(vc, animated: true)
    }
    
    private func saveConversation(conversation: ConversationResponse) {
        guard UIApplication.currentConversationId() != conversation.conversationId else {
            superView?.dismissPopupControllerAnimated()
            return
        }

        DispatchQueue.global().async { [weak self] in
            guard ConversationDAO.shared.createConversation(conversation: conversation, targetStatus: .SUCCESS), let targetConversation = ConversationDAO.shared.getConversation(conversationId: conversation.conversationId)  else {
                self?.superView?.dismissPopupControllerAnimated()
                return
            }
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }

                let vc = ConversationViewController.instance(conversation: targetConversation)
                UIApplication.currentActivity()?.navigationController?.pushViewController(withBackRoot: vc)
                weakSelf.superView?.dismissPopupControllerAnimated()
            }
        }
    }
    
    class func instance() -> GroupView {
        return Bundle.main.loadNibNamed("GroupView", owner: nil, options: nil)?.first as! GroupView
    }
    
}

extension GroupView {
    
    private func editAnnouncementAction() {
        UIApplication.homeNavigationController?.pushViewController(GroupAnnouncementViewController.instance(conversation: conversation), animated: true)
    }

    private func editGroupNameAction() {
        changeNameController.textFields?[0].text = conversation.name
        UIApplication.currentActivity()?.present(changeNameController, animated: true, completion: nil)
    }
    
    private func clearChatAction() {
        let conversationId = conversation.conversationId
        DispatchQueue.global().async {
            MessageDAO.shared.clearChat(conversationId: conversationId)
            DispatchQueue.main.async {
                showAutoHiddenHud(style: .notification, text: Localized.GROUP_CLEAR_SUCCESS)
            }
        }
    }
    
    func searchConversationAction() {
        let vc = InConversationSearchViewController()
        vc.load(group: conversation)
        let container = ContainerViewController.instance(viewController: vc, title: conversation.name)
        UIApplication.homeNavigationController?.pushViewController(container, animated: true)
    }
    
    func showSharedMediaAction() {
        let vc = R.storyboard.chat.shared_media()!
        vc.conversationId = conversation.conversationId
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.chat_shared_media())
        UIApplication.homeNavigationController?.pushViewController(container, animated: true)
    }
    
    private func exitGroupAction() {
        let conversationId = conversation.conversationId
        DispatchQueue.global().async {
            ConversationDAO.shared.makeQuitConversation(conversationId: conversationId)
            NotificationCenter.default.postOnMain(name: .ConversationDidChange, object: nil)
            DispatchQueue.main.async {
                UIApplication.homeNavigationController?.backToHome()
            }
        }
    }

    private func muteAction() {
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.PROFILE_MUTE_DURATION_8H, style: .default, handler: { [weak self](alert) in
            self?.saveMuteUntil(muteIntervalInSeconds: muteDuration8H)
        }))
        alc.addAction(UIAlertAction(title: Localized.PROFILE_MUTE_DURATION_1WEEK, style: .default, handler: { [weak self](alert) in
            self?.saveMuteUntil(muteIntervalInSeconds: muteDuration1Week)
        }))
        alc.addAction(UIAlertAction(title: Localized.PROFILE_MUTE_DURATION_1YEAR, style: .default, handler: { [weak self](alert) in
            self?.saveMuteUntil(muteIntervalInSeconds: muteDuration1Year)
        }))
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        UIApplication.currentActivity()?.present(alc, animated: true, completion: nil)
    }

    private func unmuteAction() {
        saveMuteUntil(muteIntervalInSeconds: 0)
    }

    private func saveMuteUntil(muteIntervalInSeconds: Int64) {
        let conversationId = conversation.conversationId
        NotificationCenter.default.postOnMain(name: .ConversationDidChange, object: ConversationChange(conversationId: conversationId, action: .startedUpdateConversation))
        ConversationAPI.shared.mute(conversationId: conversationId, duration: muteIntervalInSeconds) { [weak self] (result) in
            switch result {
            case let .success(response):
                self?.conversation.muteUntil = response.muteUntil
                ConversationDAO.shared.updateConversationMuteUntil(conversationId: conversationId, muteUntil: response.muteUntil)
                let toastMessage: String
                if muteIntervalInSeconds == 0 {
                    toastMessage = Localized.PROFILE_TOAST_UNMUTED
                } else {
                    toastMessage = Localized.PROFILE_TOAST_MUTED(muteUntil: DateFormatter.dateSimple.string(from: response.muteUntil.toUTCDate()))
                }
                showAutoHiddenHud(style: .notification, text: toastMessage)
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }

    private func changeNameAction() {
        NotificationCenter.default.postOnMain(name: .ConversationDidChange, object: ConversationChange(conversationId: conversation.conversationId, action: .startedUpdateConversation))
        ConversationAPI.shared.updateGroupName(conversationId: conversation.conversationId, name: newName) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case .success:
                weakSelf.conversation.name = weakSelf.newName
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }

    @objc func checkNewNameAction(_ sender: Any) {
        changeNameController.actions[1].isEnabled = !newName.isEmpty && newName.count <= 25
    }
}

extension GroupView: CollapsingLabelDelegate {
    
    func coreTextLabel(_ label: CoreTextLabel, didSelectURL url: URL) {
        guard let parent = UIApplication.homeNavigationController?.visibleViewController else {
            return
        }
        guard !openUrlOutsideApplication(url) else {
            return
        }
        superView?.dismissPopupControllerAnimated()
        if !UrlWindow.checkUrl(url: url) {
            WebViewController.presentInstance(with: .init(conversationId: "", initialUrl: url), asChildOf: parent)
        }
    }
    
    func collapsingLabel(_ label: CollapsingLabel, didChangeModeTo newMode: CollapsingLabel.Mode) {
        let announcementSize = announcementLabel.intrinsicContentSize
        announcementScrollViewHeightConstraint.constant = announcementSize.height
        announcementScrollView.isScrollEnabled = newMode == .normal && announcementSize.height > announcementScrollView.frame.height
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut], animations: {
            self.superView?.layoutIfNeeded()
        }, completion: nil)
    }

}
