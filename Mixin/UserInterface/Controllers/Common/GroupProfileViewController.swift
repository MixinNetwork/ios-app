import UIKit
import MixinServices

final class GroupProfileViewController: ProfileViewController {
    
    override var conversationId: String {
        return conversation.conversationId
    }

    override var conversationName: String {
        return conversation.name
    }
    
    override var isMuted: Bool {
        return conversation.isMuted
    }
    
    private let conversation: ConversationItem
    private let response: ConversationResponse?
    private let codeId: String?
    private var isMember: Bool
    private var participantsCount: Int?
    
    private lazy var notMemberPaddingView = NotMemberPaddingView()
    
    private var isAdmin = false
    
    init(conversation: ConversationItem, numberOfParticipants: Int?, isMember: Bool) {
        self.conversation = conversation
        self.response = nil
        self.codeId = nil
        self.isMember = isMember
        self.participantsCount = numberOfParticipants
        super.init(nibName: R.nib.profileView.name, bundle: R.nib.profileView.bundle)
        modalPresentationStyle = .custom
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
    }
    
    init(response: ConversationResponse, codeId: String, participants: [ParticipantUser], isMember: Bool) {
        self.conversation = ConversationItem(response: response)
        self.response = response
        self.codeId = codeId
        self.isMember = isMember
        self.participantsCount = response.participants.count
        super.init(nibName: R.nib.profileView.name, bundle: R.nib.profileView.bundle)
        modalPresentationStyle = .custom
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        reloadData()
        reloadCircles(conversationId: conversationId, userId: nil)
        updatePreferredContentSizeHeight(size: size)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(participantDidChange(_:)),
                                               name: ParticipantDAO.participantDidChangeNotification,
                                               object: nil)
    }
    
    override func updateMuteInterval(inSeconds interval: Int64) {
        let conversationId = conversation.conversationId
        NotificationCenter.default.post(onMainThread: MixinServices.conversationDidChangeNotification, object: ConversationChange(conversationId: conversationId, action: .startedUpdateConversation))
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        let conversationRequest = ConversationRequest(conversationId: conversationId, name: nil, category: ConversationCategory.GROUP.rawValue, participants: nil, duration: interval, announcement: nil)
        ConversationAPI.mute(conversationId: conversationId, conversationRequest: conversationRequest) { [weak self] (result) in
            switch result {
            case let .success(response):
                self?.conversation.muteUntil = response.muteUntil
                self?.reloadData()
                ConversationDAO.shared.updateConversationMuteUntil(conversationId: conversationId, muteUntil: response.muteUntil)
                let toastMessage: String
                if interval == MuteInterval.none {
                    toastMessage = R.string.localizable.unmuted()
                } else {
                    let dateRepresentation = DateFormatter.dateSimple.string(from: response.muteUntil.toUTCDate())
                    toastMessage = R.string.localizable.mute_until(dateRepresentation)
                }
                hud.set(style: .notification, text: toastMessage)
            case let .failure(error):
                hud.set(style: .error, text: error.localizedDescription)
            }
            hud.scheduleAutoHidden()
        }
    }
    
}

// MARK: - Actions
extension GroupProfileViewController {
    
    @objc func showParticipants() {
        let vc = GroupParticipantsViewController.instance(conversation: conversation)
        dismissAndPush(vc)
    }
    
    @objc func sendMessage(_ button: BusyButton) {
        guard let response = response else {
            // Currently group profile without response is only
            // triggered by tapping on Converation's top right icon
            dismiss(animated: true, completion: nil)
            return
        }
        guard UIApplication.currentConversationId() != conversation.conversationId else {
            dismiss(animated: true, completion: nil)
            return
        }
        button.isBusy = true
        showConversation(with: response)
    }
    
    @objc func joinGroup() {
        guard let codeId = codeId, !codeId.isEmpty else {
            return
        }
        relationshipView.isBusy = true
        ConversationAPI.joinConversation(codeId: codeId) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case .success(let response):
                weakSelf.showConversation(with: response)
            case let .failure(error):
                weakSelf.relationshipView.isBusy = false
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
    @objc func showSharedMedia() {
        let vc = R.storyboard.chat.shared_media()!
        vc.conversationId = conversation.conversationId
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.shared_media())
        dismissAndPush(container)
    }
    
    @objc func searchConversation() {
        let vc = InConversationSearchViewController()
        vc.load(group: conversation)
        let container = ContainerViewController.instance(viewController: vc, title: conversation.name)
        dismissAndPush(container)
    }
    
    @objc func editAnnouncement() {
        let vc = GroupAnnouncementViewController.instance(conversation: conversation)
        dismissAndPush(vc)
    }
    
    @objc func editGroupName() {
        let conversation = self.conversation
        presentEditNameController(title: R.string.localizable.change_name(), text: conversation.name, placeholder: R.string.localizable.new_name()) { [weak self] (name) in
            NotificationCenter.default.post(onMainThread: MixinServices.conversationDidChangeNotification, object: ConversationChange(conversationId: conversation.conversationId, action: .startedUpdateConversation))
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            ConversationAPI.updateGroupName(conversationId: conversation.conversationId, name: name) { (result) in
                switch result {
                case .success:
                    self?.conversation.name = name
                    self?.titleLabel.text = name
                    hud.set(style: .notification, text: R.string.localizable.changed())
                case let .failure(error):
                    hud.set(style: .error, text: error.localizedDescription)
                }
                hud.scheduleAutoHidden()
            }
        }
    }
    
    @objc func exitGroupAction() {
        let conversationId = conversation.conversationId
        let alert = UIAlertController(title: R.string.localizable.exit_confirmation(conversation.name), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.exit_group(), style: .destructive, handler: { (_) in
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            ConversationAPI.exitConversation(conversationId: conversationId) { [weak self](result) in
                let exitSuccessBlock = {
                    self?.conversation.status = ConversationStatus.QUIT.rawValue
                    hud.set(style: .notification, text: R.string.localizable.done())
                    DispatchQueue.global().async {
                        ConversationDAO.shared.exitGroup(conversationId: conversationId)
                        DispatchQueue.main.async {
                            if let count = self?.participantsCount {
                                self?.participantsCount = count - 1
                            }
                            self?.reloadData()
                        }
                    }
                }
                switch result {
                case .success:
                    exitSuccessBlock()
                case let .failure(error):
                    switch error {
                    case .forbidden, .notFound:
                        exitSuccessBlock()
                    default:
                        hud.set(style: .error, text: error.localizedDescription)
                    }
                }
                hud.scheduleAutoHidden()
            }
        }))
        present(alert, animated: true, completion: nil)
    }

    @objc func deleteChatAction() {
        let conversationId = conversation.conversationId
        let alert = UIAlertController(title: R.string.localizable.delete_group_chat_confirmation(conversation.name), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.delete_chat(), style: .destructive, handler: { [weak self](_) in
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            DispatchQueue.global().async {
                ConversationDAO.shared.deleteChat(conversationId: conversationId)
                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }
                    self.checkedDismiss(animated: true) { _ in
                        hud.set(style: .notification, text: R.string.localizable.done())
                        hud.scheduleAutoHidden()
                        if UIApplication.currentConversationId() == conversationId {
                            UIApplication.homeNavigationController?.backToHome()
                        }
                    }
                }
            }
        }))
        present(alert, animated: true, completion: nil)
    }
    
    @objc func editExpiredMessageDuration() {
        guard isAdmin else {
            return
        }
        let controller = ExpiredMessageViewController.instance(conversationId: conversationId, expireIn: conversation.expireIn)
        dismissAndPush(controller)
    }
    
    @objc func participantDidChange(_ notification: Notification) {
        guard let conversationId = notification.userInfo?[ParticipantDAO.UserInfoKey.conversationId] as? String else {
            return
        }
        guard conversationId == self.conversationId else {
            return
        }
        DispatchQueue.global().async { [weak self] in
            let count = ParticipantDAO.shared.getParticipantCount(conversationId: conversationId)
            let isAdmin = ParticipantDAO.shared.isAdmin(conversationId: conversationId, userId: myUserId)
            let isParticipant = ParticipantDAO.shared.userId(myUserId, isParticipantOfConversationId: conversationId)
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.isAdmin = isAdmin
                self.isMember = isParticipant
                self.participantsCount = count
                self.updateSubtitle()
                self.updateMenuItems()
            }
        }
    }
    
}

// MARK: - Private works
extension GroupProfileViewController {
    
    class NotMemberPaddingView: UIView {
        
        override var intrinsicContentSize: CGSize {
            return CGSize(width: 320, height: 30)
        }
        
    }
    
    private func reloadData() {
        for view in centerStackView.subviews {
            view.removeFromSuperview()
        }
        
        loadAvatar()
        titleLabel.text = conversation.name
        updateSubtitle()
        
        if !isMember && codeId != nil {
            resizeRecognizer.isEnabled = false
            relationshipView.style = .joinGroup
            relationshipView.button.removeTarget(nil, action: nil, for: .allEvents)
            relationshipView.button.addTarget(self, action: #selector(joinGroup), for: .touchUpInside)
            centerStackView.addArrangedSubview(relationshipView)
        } else {
            resizeRecognizer.isEnabled = true
        }
        
        if !conversation.announcement.isEmpty {
            descriptionView.label.text = conversation.announcement
            centerStackView.addArrangedSubview(descriptionView)
        }
        
        if isMember || codeId == nil {
            shortcutView.leftShortcutButton.setImage(R.image.ic_group_member(), for: .normal)
            shortcutView.leftShortcutButton.removeTarget(nil, action: nil, for: .allEvents)
            shortcutView.leftShortcutButton.addTarget(self, action: #selector(showParticipants), for: .touchUpInside)
            shortcutView.sendMessageButton.removeTarget(nil, action: nil, for: .allEvents)
            shortcutView.sendMessageButton.addTarget(self, action: #selector(sendMessage(_:)), for: .touchUpInside)
            shortcutView.toggleSizeButton.removeTarget(nil, action: nil, for: .allEvents)
            shortcutView.toggleSizeButton.addTarget(self, action: #selector(toggleSize), for: .touchUpInside)
            centerStackView.addArrangedSubview(shortcutView)
        } else {
            centerStackView.addArrangedSubview(notMemberPaddingView)
        }
        
        updateMenuItems()
        
        let conversationId = conversation.conversationId
        DispatchQueue.global().async { [weak self] in
            let isAdmin = ParticipantDAO.shared.isAdmin(conversationId: conversationId, userId: myUserId)
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.isAdmin = isAdmin
                self.updateMenuItems()
            }
        }
    }
    
    private func loadAvatar() {
        guard conversation.iconUrl.isEmpty else {
            avatarImageView.setGroupImage(conversation: conversation)
            return
        }
        
        avatarImageView.image = R.image.ic_conversation_group()
        let conversationId = conversation.conversationId
        let response = self.response
        
        DispatchQueue.global().async { [weak self] in
            
            func setIcon(participants: [ParticipantUser]) {
                guard let image = GroupIconMaker.make(participants: participants) else {
                    return
                }
                DispatchQueue.main.async {
                    self?.avatarImageView.image = image
                }
            }
            
            if let participants = response?.participants {
                let participantIds = participants.prefix(4).map { $0.userId }
                switch UserAPI.showUsers(userIds: participantIds) {
                case let .success(users):
                    let participants = users.map {
                        ParticipantUser(conversationId: conversationId,
                                        role: "",
                                        userId: $0.userId,
                                        userFullName: $0.fullName,
                                        userAvatarUrl: $0.avatarUrl,
                                        userIdentityNumber: $0.identityNumber)
                    }
                    setIcon(participants: participants)
                case let .failure(error):
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            } else {
                let participants = ParticipantDAO.shared.getGroupIconParticipants(conversationId: conversationId)
                setIcon(participants: participants)
            }
        }
    }
    
    private func updateSubtitle() {
        if let count = participantsCount {
            subtitleLabel.text = R.string.localizable.title_participants_count(count)
        } else {
            subtitleLabel.text = nil
        }
    }
    
    private func updateMenuItems() {
        var groups = [[ProfileMenuItem]]()
        
        guard isMember || codeId == nil else {
            reloadMenu(groups: groups)
            return
        }
        
        groups.append([
            ProfileMenuItem(title: R.string.localizable.shared_media(),
                            subtitle: nil,
                            style: [],
                            action: #selector(showSharedMedia)),
            ProfileMenuItem(title: R.string.localizable.search_conversation(),
                            subtitle: nil,
                            style: [],
                            action: #selector(searchConversation))
        ])
        
        groups.append([
            ProfileMenuItem(title: R.string.localizable.disappearing_message(),
                            subtitle: ExpiredMessageDurationFormatter.string(from: conversation.expireIn),
                            style: [],
                            action: #selector(editExpiredMessageDuration))
        ])
        
        if isAdmin {
            groups.append([
                ProfileMenuItem(title: R.string.localizable.edit_group_name(),
                                subtitle: nil,
                                style: [],
                                action: #selector(editGroupName)),
                ProfileMenuItem(title: R.string.localizable.edit_group_description(),
                                subtitle: nil,
                                style: [],
                                action: #selector(editAnnouncement))
            ])
        }
        let chatBackgroundGroup = [
            ProfileMenuItem(title: R.string.localizable.chat_background(),
                            subtitle: nil,
                            style: [],
                            action: #selector(changeChatBackground))
        ]
        groups.append(chatBackgroundGroup)
        
        if isMember {
            if conversation.isMuted {
                let subtitle: String?
                if let date = conversation.muteUntil?.toUTCDate() {
                    let rep = DateFormatter.log.string(from: date)
                    subtitle = R.string.localizable.mute_until(rep)
                } else {
                    subtitle = nil
                }
                groups.append([
                    ProfileMenuItem(title: R.string.localizable.muted(),
                                    subtitle: subtitle,
                                    style: [],
                                    action: #selector(mute))
                ])
            } else {
                groups.append([
                    ProfileMenuItem(title: R.string.localizable.mute(),
                                    subtitle: nil,
                                    style: [],
                                    action: #selector(mute))
                ])
            }
        }

        if conversation.status == ConversationStatus.QUIT.rawValue {
            groups.append([
                ProfileMenuItem(title: R.string.localizable.clear_chat(),
                                subtitle: nil,
                                style: [.destructive],
                                action: #selector(clearChat)),
                ProfileMenuItem(title: R.string.localizable.delete_chat(),
                                subtitle: nil,
                                style: [.destructive],
                                action: #selector(deleteChatAction))
            ])
        } else {
            groups.append([
                ProfileMenuItem(title: R.string.localizable.clear_chat(),
                                subtitle: nil,
                                style: [.destructive],
                                action: #selector(clearChat)),
                ProfileMenuItem(title: R.string.localizable.exit_group(),
                                subtitle: nil,
                                style: [.destructive],
                                action: #selector(exitGroupAction))
            ])
        }
        
        reloadMenu(groups: groups)
        menuStackView.insertArrangedSubview(circleItemView, at: groups.count - 1)
    }
    
    private func showConversation(with response: ConversationResponse) {
        DispatchQueue.global().async { [weak self] in
            guard let conversation = ConversationDAO.shared.createConversation(conversation: response, targetStatus: .SUCCESS) ?? ConversationDAO.shared.getConversation(conversationId: response.conversationId) else {
                DispatchQueue.main.async {
                    self?.dismiss(animated: true, completion: nil)
                }
                return
            }
            DispatchQueue.main.async {
                self?.checkedDismiss(animated: true, completion: { _ in
                    let vc = ConversationViewController.instance(conversation: conversation)
                    UIApplication.homeNavigationController?.pushViewController(withBackRoot: vc)
                })
            }
        }
    }
    
}
