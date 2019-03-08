import Foundation
import SDWebImage
import SwiftMessages
import MobileCoreServices
import RSKImageCropper
import Photos

class UserView: CornerView {

    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var fullnameLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var relationWrapperView: UIView!
    @IBOutlet weak var unblockButton: BusyButton!
    @IBOutlet weak var addContactButton: BusyButton!
    @IBOutlet weak var descriptionScrollView: UIScrollView!
    @IBOutlet weak var descriptionLabel: CollapsingLabel!
    @IBOutlet weak var openAppButton: UIButton!
    @IBOutlet weak var shareContactButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var verifiedImageView: UIImageView!
    @IBOutlet weak var moreButton: StateResponsiveButton!
    @IBOutlet weak var developButton: CornerButton!
    @IBOutlet weak var appPlaceView: UIView!
    
    @IBOutlet weak var showRelationWrapperDescriptionTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideRelationWrapperDescriptionTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var descriptionScrollViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var descriptionScrollViewHeightConstraint: NSLayoutConstraint!
    
    private weak var superView: BottomSheetView?
    private var user: UserItem!
    private var isMe = false
    private var appCreator: UserItem?
    private var relationship = ""
    private var conversationId: String {
        return ConversationDAO.shared.makeConversationId(userId: AccountAPI.shared.accountUserId, ownerUserId: user.userId)
    }

    private lazy var editAliasNameController: UIAlertController = {
        let vc = UIApplication.currentActivity()!.alertInput(title: Localized.PROFILE_EDIT_NAME, placeholder: Localized.PROFILE_FULL_NAME, handler: { [weak self](_) in
            self?.saveAliasNameAction()
        })
        vc.textFields?.first?.addTarget(self, action: #selector(alertInputChangedAction(_:)), for: .editingChanged)
        return vc
    }()
    private lazy var avatarPicker = ImagePickerController(initialCameraPosition: .front, cropImageAfterPicked: true, parent: UIApplication.currentActivity()!, delegate: self)

    override func awakeFromNib() {
        super.awakeFromNib()
        descriptionLabel.delegate = self
    }
    
    @objc func alertInputChangedAction(_ sender: Any) {
        guard let text = editAliasNameController.textFields?.first?.text else {
            return
        }
        editAliasNameController.actions[1].isEnabled = !text.isEmpty
    }

    func updateUser(user: UserItem, animated: Bool = false, refreshUser: Bool = true, superView: BottomSheetView?) {
        self.superView = superView
        self.user = user
        avatarImageView.setImage(with: user)
        fullnameLabel.text = user.fullName
        idLabel.text = Localized.PROFILE_MIXIN_ID(id: user.identityNumber)
        verifiedImageView.isHidden = !user.isVerified
        developButton.isHidden = true
        isMe = user.userId == AccountAPI.shared.accountUserId

        if let creatorId = user.appCreatorId {
            DispatchQueue.global().async { [weak self] in
                var creator = UserDAO.shared.getUser(userId: creatorId)
                if creator == nil {
                    switch UserAPI.shared.showUser(userId: creatorId) {
                    case let .success(user):
                        UserDAO.shared.updateUsers(users: [user], sendNotificationAfterFinished: false)
                        creator = UserItem.createUser(from: user)
                    case .failure:
                        return
                    }
                }
                self?.appCreator = creator
                if let creatorFullname = creator?.fullName {
                    DispatchQueue.main.async {
                        UIView.performWithoutAnimation {
                            self?.developButton.setTitle(creatorFullname, for: .normal)
                            self?.developButton.isHidden = false
                        }
                    }
                }
            }
        }

        if user.isVerified {
            verifiedImageView.image = #imageLiteral(resourceName: "ic_user_verified")
            verifiedImageView.isHidden = false
        } else if user.isBot {
            verifiedImageView.image = #imageLiteral(resourceName: "ic_user_bot")
            verifiedImageView.isHidden = false
        } else {
            verifiedImageView.isHidden = true
        }
        
        layoutIfNeeded()
        if user.isBot, let appDescription = user.appDescription, !appDescription.isEmpty {
            descriptionLabel.text = appDescription
            descriptionScrollViewBottomConstraint.constant = 14
            descriptionScrollViewHeightConstraint.constant = descriptionLabel.intrinsicContentSize.height
            descriptionLabel.isHidden = false
            developButton.isHidden = false
            appPlaceView.isHidden = false
        } else {
            descriptionScrollViewBottomConstraint.constant = 8
            descriptionScrollViewHeightConstraint.constant = 0
            descriptionLabel.isHidden = true
            developButton.isHidden = true
            appPlaceView.isHidden = true
        }

        if isMe {
            addContactButton.isHidden = true
            openAppButton.isHidden = true
            sendButton.isHidden = true
            shareContactButton.isHidden = false
        } else {
            if refreshUser {
                UserAPI.shared.showUser(userId: user.userId) { [weak self](result) in
                    self?.handlerUpdateUser(result)
                }
            }

            guard user.relationship != relationship else {
                return
            }
            relationship = user.relationship
            let isBlocked = user.relationship == Relationship.BLOCKING.rawValue
            let isStranger = user.relationship == Relationship.STRANGER.rawValue
            
            if isBlocked {
                unblockButton.isHidden = false
                addContactButton.isHidden = true
                showRelationWrapperDescriptionTopConstraint.priority = .defaultHigh
                hideRelationWrapperDescriptionTopConstraint.priority = .defaultLow
            } else if isStranger {
                unblockButton.isHidden = true
                addContactButton.isHidden = false
                showRelationWrapperDescriptionTopConstraint.priority = .defaultHigh
                hideRelationWrapperDescriptionTopConstraint.priority = .defaultLow
            } else {
                unblockButton.isHidden = true
                addContactButton.isHidden = true
                showRelationWrapperDescriptionTopConstraint.priority = .defaultLow
                hideRelationWrapperDescriptionTopConstraint.priority = .defaultHigh
            }
            
            shareContactButton.isHidden = user.isBot
            openAppButton.isHidden = !user.isBot
        }
    }

    @IBAction func appCreatorAction(_ sender: Any) {
        guard let creator = appCreator else {
            return
        }

        if user.appCreatorId == AccountAPI.shared.accountUserId {
            guard let account = AccountAPI.shared.account else {
                return
            }
            updateUser(user: UserItem.createUser(from: account), animated: true, superView: superView)
        } else {
            updateUser(user: creator, animated: true, superView: superView)
        }
    }

    @IBAction func dismissAction(_ sender: Any) {
        superView?.dismissPopupControllerAnimated()
    }

    @IBAction func moreAction(_ sender: Any) {
        superView?.dismissPopupControllerAnimated()
        let alc = UIAlertController(title: user.fullName, message: user.phone ?? user.identityNumber, preferredStyle: .actionSheet)
        if user.isBot {
            alc.addAction(UIAlertAction(title: Localized.PROFILE_OPEN_BOT, style: .default, handler: { [weak self](action) in
                self?.openApp()
            }))
        }

        if isMe {
            alc.addAction(UIAlertAction(title: Localized.PROFILE_EDIT_NAME, style: .default, handler: { [weak self](action) in
                self?.editNameAction()
            }))
            alc.addAction(UIAlertAction(title: Localized.PROFILE_CHANGE_AVATAR, style: .default, handler: { [weak self](action) in
                self?.changeProfilePhoto()
            }))
            alc.addAction(UIAlertAction(title: Localized.PROFILE_CHANGE_NUMBER, style: .default, handler: { [weak self](action) in
                self?.changeNumber()
            }))
        } else {
            alc.addAction(UIAlertAction(title: Localized.PROFILE_SHARE_CARD, style: .default, handler: { [weak self](action) in
                self?.shareAction(alc)
            }))
            alc.addAction(UIAlertAction(title: Localized.PROFILE_TRANSACTIONS, style: .default, handler: { [weak self](action) in
                self?.transactionsAction()
            }))
        }
        switch user.relationship {
        case Relationship.FRIEND.rawValue:
            alc.addAction(UIAlertAction(title: Localized.PROFILE_EDIT_NAME, style: .default, handler: { [weak self](action) in
                self?.editNameAction()
            }))
            addMuteAlertAction(alc: alc)
            alc.addAction(UIAlertAction(title: Localized.PROFILE_REMOVE, style: .destructive, handler: { [weak self](action) in
                self?.removeAction()
            }))
        case Relationship.STRANGER.rawValue:
            addMuteAlertAction(alc: alc)
            alc.addAction(UIAlertAction(title: Localized.PROFILE_BLOCK, style: .destructive, handler: { [weak self](action) in
                self?.blockAction()
            }))
        default:
            break
        }
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        UIApplication.currentActivity()?.present(alc, animated: true, completion: nil)
    }

    @IBAction func previewAvatarAction(_ sender: Any) {
        guard !user.avatarUrl.isEmpty, avatarImageView.sd_imageProgress.isFinished, let superView = superView as? UserWindow else {
            return
        }
        let frame = avatarImageView.convert(avatarImageView.bounds, to: superView)
        let avatarPreviewImageView = AvatarPreviewImageView(frame: frame)
        avatarPreviewImageView.image = avatarImageView.image
        avatarPreviewImageView.layer.cornerRadius = avatarImageView.layer.cornerRadius
        avatarPreviewImageView.clipsToBounds = true
        avatarImageView.isHidden = true
        superView.addSubview(avatarPreviewImageView)
        superView.contentBottomConstraint.constant = -self.frame.height - superView.compatibleSafeAreaInsets.vertical
        UIView.animate(withDuration: 0.25, animations: {
            superView.layoutIfNeeded()
            avatarPreviewImageView.layer.cornerRadius = 0
            avatarPreviewImageView.bounds.size = CGSize(width: superView.frame.width,
                                                        height: superView.frame.width)
            avatarPreviewImageView.center = CGPoint(x: superView.frame.width / 2,
                                                    y: superView.frame.height / 2)
        }, completion: { (finished: Bool) -> Void in
            superView.userViewPopupView = superView.popupView
            superView.popupView = avatarPreviewImageView
        })
    }
    
    @IBAction func shareAction(_ sender: Any) {
        let vc = SendMessagePeerSelectionViewController.instance(content: .contact(user.userId))
        UIApplication.rootNavigationController()?.pushViewController(vc, animated: true)
    }
    
    @IBAction func openApp(_ sender: Any) {
        superView?.dismissPopupControllerAnimated()
        openApp()
    }

    private func changeNumber() {
        UIApplication.rootNavigationController()?.present(ChangeNumberNavigationController.instance(), animated: true, completion: nil)
    }
    
    private func openApp() {
        let userId = user.userId
        let conversationId: String
        if let vc = UIApplication.rootNavigationController()?.viewControllers.last as? ConversationViewController {
            conversationId = vc.conversationId
        } else {
            conversationId = self.conversationId
        }
        DispatchQueue.global().async {
            guard let app = AppDAO.shared.getApp(ofUserId: userId), let url = URL(string: app.homeUri) else {
                return
            }
            DispatchQueue.main.async {
                WebWindow.instance(conversationId: conversationId, app: app).presentPopupControllerAnimated(url: url)
            }
        }
    }
    
    private func addMuteAlertAction(alc: UIAlertController) {
        if user.isMuted {
            alc.addAction(UIAlertAction(title: Localized.PROFILE_UNMUTE, style: .default, handler: { [weak self](action) in
                self?.unmuteAction()
            }))
        } else {
            alc.addAction(UIAlertAction(title: Localized.PROFILE_MUTE, style: .default, handler: { [weak self](action) in
                self?.muteAction()
            }))
        }
    }

    private func saveAliasNameAction() {
        guard let newName = editAliasNameController.textFields?.first?.text, !newName.isEmpty else {
            return
        }
        showLoading()
        if isMe {
            AccountAPI.shared.update(fullName: newName) { [weak self] (result) in
                switch result {
                case let .success(account):
                    if let weakSelf = self {
                        weakSelf.updateUser(user: UserItem.createUser(from: account), animated: true, refreshUser: false, superView: weakSelf.superView)
                    }
                    AccountAPI.shared.account = account
                    DispatchQueue.global().async {
                        UserDAO.shared.updateAccount(account: account)
                    }
                case .failure:
                    break
                }
            }
        } else {
            UserAPI.shared.remarkFriend(userId: user.userId, full_name: newName) { [weak self](result) in
                self?.handlerUpdateUser(result)
            }
        }
    }
    
    private func transactionsAction() {
        UIApplication.rootNavigationController()?.pushViewController(PeerTransactionsViewController.instance(opponentId: user.userId), animated: true)
    }

    private func blockAction() {
        showLoading()
        UserAPI.shared.blockUser(userId: user.userId) { [weak self](result) in
            self?.handlerUpdateUser(result)
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
        showLoading()
        let userId = user.userId
        ConversationAPI.shared.mute(userId: userId, duration: muteIntervalInSeconds) { [weak self] (result) in
            switch result {
            case let .success(response):
                self?.user.muteUntil = response.muteUntil
                UserDAO.shared.updateNotificationEnabled(userId: userId, muteUntil: response.muteUntil)
                let toastMessage: String
                if muteIntervalInSeconds == 0 {
                    toastMessage = Localized.PROFILE_TOAST_UNMUTED
                } else {
                    toastMessage = Localized.PROFILE_TOAST_MUTED(muteUntil: DateFormatter.dateSimple.string(from: response.muteUntil.toUTCDate()))
                }
                NotificationCenter.default.postOnMain(name: .ToastMessageDidAppear, object: toastMessage)
            case .failure:
                break
            }
        }
    }

    private func editNameAction() {
        editAliasNameController.textFields?.first?.text = user.fullName
        UIApplication.currentActivity()?.present(editAliasNameController, animated: true, completion: nil)
    }

    private func removeAction() {
        showLoading()
        UserAPI.shared.removeFriend(userId: user.userId, completion: { [weak self](result) in
            self?.handlerUpdateUser(result, notifyContact: true)
        })
    }

    private func handlerUpdateUser(_ result: APIResult<UserResponse>, notifyContact: Bool = false, successBlock: (() -> Void)? = nil) {
        switch result {
        case let .success(user):
            UserDAO.shared.updateUsers(users: [user], notifyContact: notifyContact)
            updateUser(user: UserItem.createUser(from: user), animated: true, refreshUser: false, superView: superView)
            successBlock?()
        case .failure:
            break
        }
    }
    
    @IBAction func sendAction(_ sender: Any) {
        superView?.dismissPopupControllerAnimated()
        if let conversationVC = UIApplication.rootNavigationController()?.viewControllers.last as? ConversationViewController, conversationVC.dataSource?.category == ConversationDataSource.Category.contact && conversationVC.dataSource?.conversation.ownerId == user.userId {
            return
        }

        UIApplication.rootNavigationController()?.pushViewController(withBackRoot: ConversationViewController.instance(ownerUser: user))
    }
    
    @IBAction func addAction(_ sender: Any) {
        guard !addContactButton.isBusy else {
            return
        }
        addContactButton.isBusy = true
        UserAPI.shared.addFriend(userId: user.userId, full_name: user.fullName, completion: { [weak self] (result) in
            self?.handlerUpdateUser(result, notifyContact: true, successBlock: {
                self?.addContactButton.isBusy = false
            })
        })
    }
    
    @IBAction func unblockAction(_ sender: Any) {
        guard !unblockButton.isBusy else {
            return
        }
        unblockButton.isBusy = true
        UserAPI.shared.unblockUser(userId: user.userId) { [weak self] (result) in
            self?.handlerUpdateUser(result, notifyContact: true, successBlock: {
                self?.unblockButton.isBusy = false
            })
        }
    }
    
    private func showLoading() {
        NotificationCenter.default.postOnMain(name: .ConversationDidChange, object: ConversationChange(conversationId: conversationId, action: .startedUpdateConversation))
    }

    class func instance() -> UserView {
        return Bundle.main.loadNibNamed("UserView", owner: nil, options: nil)?.first as! UserView
    }
}

extension UserView: CollapsingLabelDelegate {
    
    func coreTextLabel(_ label: CoreTextLabel, didSelectURL url: URL) {
        dismissAction(self)
        if !UrlWindow.checkUrl(url: url) {
            WebWindow.instance(conversationId: conversationId).presentPopupControllerAnimated(url: url)
        }
    }
    
    func collapsingLabel(_ label: CollapsingLabel, didChangeModeTo newMode: CollapsingLabel.Mode) {
        let textSize = descriptionLabel.intrinsicContentSize
        descriptionScrollViewHeightConstraint.constant = textSize.height
        descriptionScrollView.isScrollEnabled = newMode == .normal && textSize.height > descriptionScrollView.frame.height
        layoutIfNeeded()
    }
    
}

extension UserView {
    
    class AvatarPreviewImageView: UIImageView {
        
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            return false
        }
        
    }
    
}

extension UserView: ImagePickerControllerDelegate {

    private func changeProfilePhoto() {
        guard let viewController = UIApplication.currentActivity() else {
            return
        }
        avatarPicker.viewController = viewController
        avatarPicker.delegate = self
        avatarPicker.present()
    }

    func imagePickerController(_ controller: ImagePickerController, didPickImage image: UIImage) {
        guard let avatarBase64 = image.scaledToSize(newSize: CGSize(width: 1024, height: 1024)).base64 else {
            UIApplication.currentActivity()?.alert(Localized.CONTACT_ERROR_COMPOSE_AVATAR)
            return
        }

        AccountAPI.shared.update(fullName: nil, avatarBase64: avatarBase64, completion: { (result) in
            switch result {
            case let .success(account):
                AccountAPI.shared.account = account
                DispatchQueue.global().async {
                    UserDAO.shared.updateAccount(account: account)
                }
            case .failure:
                break
            }
        })
    }

}
