import UIKit
import Alamofire
import SwiftMessages

class GroupView: CornerView {
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var announcementScrollView: UIScrollView!
    @IBOutlet weak var announcementLabel: CollapsingLabel!
    @IBOutlet weak var participantView1: AvatarImageView!
    @IBOutlet weak var participantView2: AvatarImageView!
    @IBOutlet weak var participantView3: AvatarImageView!
    @IBOutlet weak var participantView4: AvatarImageView!
    @IBOutlet weak var participantCountLabel: ConerLabel!
    @IBOutlet weak var joinTopLineView: UIView!
    @IBOutlet weak var joinBottomLineView: UIView!
    @IBOutlet weak var joinButton: StateResponsiveButton!
    @IBOutlet weak var participantsView: UIStackView!
    @IBOutlet weak var moreButton: StateResponsiveButton!

    @IBOutlet weak var announcementScrollViewHeightConstraint: NSLayoutConstraint!
    
    private weak var superView: BottomSheetView?
    private var conversation: ConversationItem!
    private var codeId: String?
    private var initialAnnouncementMode = CollapsingLabel.Mode.collapsed
    private var isAdmin = false

    private lazy var participantViews = [participantView1, participantView2, participantView3, participantView4]

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
        participantsView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(participentsAction(_:))))
    }

    func render(codeId: String, conversation: ConversationResponse, ownerUser: UserItem, participants: [ParticipantUser], alreadyInTheGroup: Bool, superView: BottomSheetView) {
        self.superView = superView
        self.conversation = ConversationItem.createConversation(from: conversation)
        self.codeId = codeId

        renderConversation(alreadyInTheGroup: alreadyInTheGroup)
        renderParticipants(participants: participants, participantCount: conversation.participants.count)
    }

    func render(conversation: ConversationItem, superView: BottomSheetView, initialAnnouncementMode: CollapsingLabel.Mode) {
        self.superView = superView
        self.conversation = conversation
        self.initialAnnouncementMode = initialAnnouncementMode

        renderConversation()

        let conversationId = conversation.conversationId
        DispatchQueue.global().async { [weak self] in
            let participents = ParticipantDAO.shared.getGroupIconParticipants(conversationId: conversationId)
            let participantCount = ParticipantDAO.shared.getCount(conversationId: conversationId)
            self?.isAdmin = ParticipantDAO.shared.isAdmin(conversationId: conversationId, userId: AccountAPI.shared.accountUserId)
            DispatchQueue.main.async {
                self?.renderParticipants(participants: participents, participantCount: participantCount)
            }
        }
    }

    private func renderConversation(alreadyInTheGroup: Bool = true) {
        joinTopLineView.isHidden = alreadyInTheGroup
        joinBottomLineView.isHidden = alreadyInTheGroup
        joinButton.isHidden = alreadyInTheGroup
        moreButton.isHidden = !alreadyInTheGroup

        avatarImageView.setGroupImage(with: conversation.iconUrl, conversationId: conversation.conversationId)
        nameLabel.text = conversation.name
        announcementLabel.mode = initialAnnouncementMode
        announcementLabel.isHidden = conversation.announcement.isEmpty
        announcementLabel.text = conversation.announcement
    }

    private func renderParticipants(participants: [ParticipantUser], participantCount: Int) {
        for idx in 0..<4 {
            let participantView = participantViews[idx]
            if idx < participants.count {
                participantView?.setImage(user: participants[idx])
                participantView?.isHidden = false
            } else {
                participantView?.isHidden = true
            }
        }
        if participantCount > 4 {
            participantCountLabel.text = "+\(participantCount - 4)"
            participantCountLabel.isHidden = false
        } else {
            participantCountLabel.isHidden = true
        }
    }

    @IBAction func moreAction(_ sender: Any) {
        superView?.dismissPopupControllerAnimated()
        let alc = UIAlertController(title: conversation.name, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.GROUP_MENU_PARTICIPANTS, style: .default, handler: { [weak self] (action) in
            self?.participantSettingsAction()
        }))
        if isAdmin {
            alc.addAction(UIAlertAction(title: Localized.GROUP_MENU_ANNOUNCEMENT, style: .default, handler: { [weak self](action) in
                self?.editAnnouncementAction()
            }))
            alc.addAction(UIAlertAction(title: Localized.PROFILE_EDIT_NAME, style: .default, handler: { [weak self](action) in
                self?.editGroupNameAction()
            }))
        }
        if conversation.isMuted {
            alc.addAction(UIAlertAction(title: Localized.PROFILE_UNMUTE, style: .default, handler: { [weak self](action) in
                self?.unmuteAction()
            }))
        } else {
            alc.addAction(UIAlertAction(title: Localized.PROFILE_MUTE, style: .default, handler: { [weak self](action) in
                self?.muteAction()
            }))
        }
        alc.addAction(UIAlertAction(title: Localized.GROUP_MENU_CLEAR, style: .destructive, handler: { [weak self] (action) in
            self?.clearChatAction()
        }))
        alc.addAction(UIAlertAction(title: Localized.GROUP_MENU_EXIT, style: .destructive, handler: { [weak self] (action) in
            self?.exitGroupAction()
        }))

        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        UIApplication.currentActivity()?.present(alc, animated: true, completion: nil)
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
            case let .failure(error, _):
                weakSelf.joinButton.isBusy = false
                SwiftMessages.showToast(message: error.kind.localizedDescription ?? Localized.TOAST_OPERATION_FAILED, backgroundColor: .hintRed)
            }
        }
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        superView?.dismissPopupControllerAnimated()
    }

    private func saveConversation(conversation: ConversationResponse) {
        DispatchQueue.global().async { [weak self] in
            guard ConversationDAO.shared.createConversation(conversation: conversation, targetStatus: .SUCCESS) else {
                self?.superView?.dismissPopupControllerAnimated()
                return
            }
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }

                let vc = ConversationViewController.instance(conversation: ConversationItem.createConversation(from: conversation))
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

    @objc func participentsAction(_ recognizer: UIGestureRecognizer) {
        superView?.dismissPopupControllerAnimated()
        participantSettingsAction()
    }

    private func editAnnouncementAction() {
        UIApplication.rootNavigationController()?.pushViewController(GroupAnnouncementViewController.instance(conversation: conversation), animated: true)
    }

    private func editGroupNameAction() {
        changeNameController.textFields?[0].text = conversation.name
        UIApplication.currentActivity()?.present(changeNameController, animated: true, completion: nil)
    }

    private func participantSettingsAction() {
        UIApplication.rootNavigationController()?.pushViewController(GroupParticipentViewController.instance(conversation: conversation), animated: true)
    }

    private func clearChatAction() {
        let conversationId = conversation.conversationId
        DispatchQueue.global().async {
            MessageDAO.shared.clearChat(conversationId: conversationId)
            NotificationCenter.default.postOnMain(name: .ToastMessageDidAppear, object: Localized.GROUP_CLEAR_SUCCESS)
        }
    }

    private func exitGroupAction() {
        let conversationId = conversation.conversationId
        DispatchQueue.global().async {
            ConversationDAO.shared.makeQuitConversation(conversationId: conversationId)
            NotificationCenter.default.postOnMain(name: .ConversationDidChange, object: nil)
            DispatchQueue.main.async {
                UIApplication.rootNavigationController()?.backToHome()
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
                NotificationCenter.default.postOnMain(name: .ToastMessageDidAppear, object: toastMessage)
            case let .failure(error, didHandled):
                guard !didHandled else {
                    return
                }
                NotificationCenter.default.postOnMain(name: .ErrorMessageDidAppear, object: error.kind.localizedDescription ?? error.description)
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
            case let .failure(_, didHandled):
                guard !didHandled else {
                    return
                }
                NotificationCenter.default.postOnMain(name: .ErrorMessageDidAppear, object: Localized.TOAST_OPERATION_FAILED)
            }
        }
    }

    @objc func checkNewNameAction(_ sender: Any) {
        changeNameController.actions[1].isEnabled = !newName.isEmpty && newName.count <= 25
    }
}

extension GroupView: CollapsingLabelDelegate {
    
    func coreTextLabel(_ label: CoreTextLabel, didSelectURL url: URL) {
        superView?.dismissPopupControllerAnimated()
        if !UrlWindow.checkUrl(url: url) {
            WebWindow.instance(conversationId: "").presentPopupControllerAnimated(url: url)
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
