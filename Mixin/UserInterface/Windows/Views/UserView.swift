import Foundation
import SDWebImage
import MobileCoreServices
import RSKImageCropper
import Photos

class UserView: CornerView {
    
    @IBOutlet weak var longPressRecognizer: UILongPressGestureRecognizer!
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var fullnameLabel: UILabel!
    @IBOutlet weak var idLabel: IdentityNumberLabel!
    @IBOutlet weak var relationWrapperView: UIView!
    @IBOutlet weak var unblockButton: BusyButton!
    @IBOutlet weak var addContactButton: BusyButton!
    @IBOutlet weak var descriptionScrollView: UIScrollView!
    @IBOutlet weak var descriptionLabel: CollapsingLabel!
    @IBOutlet weak var editNameButton: UIButton!
    @IBOutlet weak var qrcodeButton: UIButton!
    @IBOutlet weak var openAppButton: UIButton!
    @IBOutlet weak var transferButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var verifiedImageView: UIImageView!
    @IBOutlet weak var moreButton: StateResponsiveButton!
    
    @IBOutlet weak var showRelationWrapperDescriptionTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideRelationWrapperDescriptionTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var descriptionScrollViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var descriptionScrollViewHeightConstraint: NSLayoutConstraint!
    
    private weak var superView: BottomSheetView?
    private var user: UserItem!
    private var isMe = false
    private var appCreator: UserItem?
    private var relationship = ""
    private var menuDismissResponder: MenuDismissResponder?
    
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
    private lazy var qrcodeWindow = QrcodeWindow.instance()
    private lazy var hud = Hud()
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        descriptionLabel.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(willHideMenu(_:)), name: UIMenuController.willHideMenuNotification, object: nil)
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return action == #selector(copy(_:))
    }
    
    override func copy(_ sender: Any?) {
        UIPasteboard.general.string = user.identityNumber
    }
    
    @objc func alertInputChangedAction(_ sender: Any) {
        guard let text = editAliasNameController.textFields?.first?.text else {
            return
        }
        editAliasNameController.actions[1].isEnabled = !text.isEmpty
    }
    
    @objc func willHideMenu(_ notification: Notification) {
        menuDismissResponder?.removeFromSuperview()
        idLabel.highlightIdentityNumber = false
    }

    func updateUser(user: UserItem, animated: Bool = false, refreshUser: Bool = true, superView: BottomSheetView?) {
        self.superView = superView
        self.user = user
        avatarImageView.setImage(with: user)
        fullnameLabel.text = user.fullName
        idLabel.identityNumber = user.identityNumber
        verifiedImageView.isHidden = !user.isVerified
        isMe = user.userId == AccountAPI.shared.accountUserId

        if let creatorId = user.appCreatorId {
            DispatchQueue.global().async { [weak self] in
                var creator = UserDAO.shared.getUser(userId: creatorId)
                if creator == nil {
                    switch UserAPI.shared.showUser(userId: creatorId) {
                    case let .success(user):
                        UserDAO.shared.updateUsers(users: [user], sendNotificationAfterFinished: false)
                        creator = UserItem.createUser(from: user)
                    case let .failure(error):
                        showAutoHiddenHud(style: .error, text: error.localizedDescription)
                    }
                }
                self?.appCreator = creator
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
        if user.biography.isEmpty {
            descriptionScrollViewBottomConstraint.constant = 8
            descriptionScrollViewHeightConstraint.constant = 0
            descriptionLabel.isHidden = true
        } else {
            descriptionLabel.text = user.biography
            descriptionScrollViewBottomConstraint.constant = 14
            descriptionScrollViewHeightConstraint.constant = descriptionLabel.intrinsicContentSize.height
            descriptionLabel.isHidden = false
        }

        if isMe {
            editNameButton.isHidden = false
            qrcodeButton.isHidden = false
            transferButton.isHidden = true
            addContactButton.isHidden = true
            openAppButton.isHidden = true
            sendButton.isHidden = true
        } else {
            editNameButton.isHidden = true
            qrcodeButton.isHidden = true
            sendButton.isHidden = false
            
            if refreshUser {
                UserAPI.shared.showUser(userId: user.userId) { [weak self](result) in
                    self?.handlerUpdateUser(result, showError: false)
                }
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
                if !user.isBot {
                    descriptionScrollViewBottomConstraint.constant = 0
                }
                showRelationWrapperDescriptionTopConstraint.priority = .defaultLow
                hideRelationWrapperDescriptionTopConstraint.priority = .defaultHigh
            }
            
            transferButton.isHidden = user.isBot
            openAppButton.isHidden = !user.isBot
        }
    }
    
    @IBAction func longPressAction(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else {
            return
        }
        becomeFirstResponder()
        idLabel.highlightIdentityNumber = true
        if let highlightedRect = idLabel.highlightedRect {
            let menu = UIMenuController.shared
            menu.setTargetRect(highlightedRect, in: idLabel)
            menu.setMenuVisible(true, animated: true)
            let menuDismissResponder: MenuDismissResponder
            if let responder = self.menuDismissResponder {
                menuDismissResponder = responder
            } else {
                menuDismissResponder = MenuDismissResponder()
                self.menuDismissResponder = menuDismissResponder
            }
            AppDelegate.current.window.addSubview(menuDismissResponder)
        }
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        superView?.dismissPopupControllerAnimated()
    }

    @IBAction func moreAction(_ sender: Any) {
        superView?.dismissPopupControllerAnimated()
        let alc = UIAlertController(title: user.fullName, message: user.phone ?? user.identityNumber, preferredStyle: .actionSheet)
        if user.isBot {
            alc.addAction(UIAlertAction(title: Localized.CHAT_MENU_DEVELOPER, style: .default, handler: { (action) in
                self.developerAction()
            }))
        }
        if isMe {
            alc.addAction(UIAlertAction(title: Localized.PROFILE_EDIT_NAME, style: .default, handler: { (action) in
                self.editName()
            }))
            alc.addAction(UIAlertAction(title: R.string.localizable.profile_edit_biography(), style: .default, handler: { (action) in
                self.editBiography()
            }))
            alc.addAction(UIAlertAction(title: Localized.PROFILE_CHANGE_AVATAR, style: .default, handler: { (action) in
                self.changeProfilePhoto()
            }))
            alc.addAction(UIAlertAction(title: Localized.PROFILE_CHANGE_NUMBER, style: .default, handler: { (action) in
                self.changeNumber()
            }))
        } else {
            alc.addAction(UIAlertAction(title: Localized.PROFILE_SHARE_CARD, style: .default, handler: { (action) in
                self.shareAction()
            }))
            alc.addAction(UIAlertAction(title: R.string.localizable.profile_search_conversation(), style: .default, handler: { (action) in
                self.searchConversationAction()
            }))
            alc.addAction(UIAlertAction(title: R.string.localizable.chat_shared_media(), style: .default, handler: { (action) in
                self.showSharedMediaAction()
            }))

            if user.isSelfBot {
                alc.addAction(UIAlertAction(title: Localized.CHAT_MENU_TRANSFER, style: .default, handler: { (action) in
                    self.transferAction(alc)
                }))
            }

            alc.addAction(UIAlertAction(title: Localized.PROFILE_TRANSACTIONS, style: .default, handler: { (action) in
                self.transactionsAction()
            }))
        }
        switch user.relationship {
        case Relationship.FRIEND.rawValue:
            alc.addAction(UIAlertAction(title: Localized.PROFILE_EDIT_NAME, style: .default, handler: { (action) in
                self.editName()
            }))
            addMuteAlertAction(alc: alc)
            alc.addAction(UIAlertAction(title: Localized.PROFILE_REMOVE, style: .destructive, handler: { (action) in
                self.removeAction()
            }))
        case Relationship.STRANGER.rawValue:
            addMuteAlertAction(alc: alc)
            alc.addAction(UIAlertAction(title: Localized.PROFILE_BLOCK, style: .destructive, handler: { (action) in
                self.blockAction()
            }))
        case Relationship.BLOCKING.rawValue:
            alc.addAction(UIAlertAction(title: Localized.PROFILE_UNBLOCK, style: .destructive, handler: { (action) in
                self.unblockAction()
            }))
        default:
            break
        }
        if !isMe {
            alc.addAction(UIAlertAction(title: Localized.GROUP_MENU_CLEAR, style: .destructive, handler: { (action) in
                self.clearChatAction()
            }))
            alc.addAction(UIAlertAction(title: R.string.localizable.profile_report(), style: .destructive, handler: { (action) in
                self.reportAction()
            }))
        }
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        UIApplication.currentActivity()?.present(alc, animated: true, completion: nil)
    }

    private func reportAction() {
        let alc = UIAlertController(title: R.string.localizable.profile_report_tips(), message: nil, preferredStyle: .alert)
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        alc.addAction(UIAlertAction(title: R.string.localizable.profile_report(), style: .destructive, handler: { (_) in
            self.reportContactAction()
        }))
        UIApplication.currentActivity()?.present(alc, animated: true, completion: nil)
    }

    private func reportContactAction() {
        showLoading()
        let userId = user.userId
        let conversationId = ConversationDAO.shared.makeConversationId(userId: AccountAPI.shared.accountUserId, ownerUserId: user.userId)

        DispatchQueue.global().async {
            switch UserAPI.shared.reportUser(userId: userId) {
            case let .success(user):
                UserDAO.shared.updateUsers(users: [user], sendNotificationAfterFinished: false)
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
            ConversationDAO.shared.deleteConversationAndMessages(conversationId: conversationId)
            MixinFile.cleanAllChatDirectories()
            NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: nil)
            DispatchQueue.main.async {
                UIApplication.homeNavigationController?.backToHome()
            }
        }
    }

    @IBAction func previewAvatarAction(_ sender: Any) {
        guard !user.avatarUrl.isEmpty, let image = avatarImageView.image, let superView = superView as? UserWindow else {
            return
        }
        let frame = avatarImageView.convert(avatarImageView.bounds, to: superView)
        let avatarPreviewImageView = AvatarPreviewImageView(frame: frame)
        avatarPreviewImageView.image = image
        avatarPreviewImageView.layer.cornerRadius = avatarImageView.layer.cornerRadius
        avatarPreviewImageView.clipsToBounds = true
        avatarImageView.isHidden = true
        superView.addSubview(avatarPreviewImageView)
        superView.contentBottomConstraint.constant = -self.frame.height - superView.safeAreaInsets.vertical
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

    func shareAction() {
        let vc = MessageReceiverViewController.instance(content: .contact(user.userId))
        UIApplication.homeNavigationController?.pushViewController(vc, animated: true)
    }

    func searchConversationAction() {
        let vc = InConversationSearchViewController()
        vc.load(user: user, conversationId: conversationId)
        let container = ContainerViewController.instance(viewController: vc, title: user.fullName)
        UIApplication.homeNavigationController?.pushViewController(container, animated: true)
    }
    
    func showSharedMediaAction() {
        let vc = R.storyboard.chat.shared_media()!
        vc.conversationId = conversationId
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.chat_shared_media())
        UIApplication.homeNavigationController?.pushViewController(container, animated: true)
    }
    
    @IBAction func transferAction(_ sender: Any) {
        superView?.dismissPopupControllerAnimated()

        let viewController: UIViewController
        if AccountAPI.shared.account?.has_pin ?? false {
            viewController = TransferOutViewController.instance(asset: nil, type: .contact(user))
        } else {
            viewController = WalletPasswordViewController.instance(dismissTarget: .transfer(user: user))
        }
        UIApplication.homeNavigationController?.pushViewController(viewController, animated: true)
    }
    
    @IBAction func openApp(_ sender: Any) {
        superView?.dismissPopupControllerAnimated()
        openApp()
    }

    @IBAction func editMyNameAction(_ sender: Any) {
        superView?.dismissPopupControllerAnimated()
        editName()
    }
    
    @IBAction func changeMyAvatarAction(_ sender: Any) {
        superView?.dismissPopupControllerAnimated()
        changeProfilePhoto()
    }

    @IBAction func qrcodeAction(_ sender: Any) {
        guard let account = AccountAPI.shared.account else {
            return
        }
        superView?.dismissPopupControllerAnimated()

        qrcodeWindow.render(title: Localized.CONTACT_MY_QR_CODE,
                            description: Localized.MYQRCODE_PROMPT,
                            account: account)
        qrcodeWindow.presentView()
    }

    private func developerAction() {
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
        superView?.presentView()
    }
    
    private func changeNumber() {
        if AccountAPI.shared.account?.has_pin ?? false {
            let viewController = VerifyPinNavigationController(rootViewController: ChangeNumberVerifyPinViewController())
            UIApplication.homeNavigationController?.present(viewController, animated: true, completion: nil)
        } else {
            let viewController = WalletPasswordViewController.instance(dismissTarget: .changePhone)
            UIApplication.homeNavigationController?.pushViewController(viewController, animated: true)
        }
    }
    
    private func openApp() {
        guard let parent = UIApplication.homeNavigationController?.visibleViewController else {
            return
        }
        let userId = user.userId
        let conversationId: String
        if let vc = UIApplication.homeNavigationController?.viewControllers.last as? ConversationViewController {
            conversationId = vc.conversationId
        } else {
            conversationId = self.conversationId
        }
        DispatchQueue.global().async {
            guard let app = AppDAO.shared.getApp(ofUserId: userId) else {
                return
            }
            UIApplication.logEvent(eventName: "open_app", parameters: ["source": "UserWindow", "identityNumber": app.appNumber])
            DispatchQueue.main.async {
                WebViewController.presentInstance(with: .init(conversationId: conversationId, app: app), asChildOf: parent)
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
                    AccountAPI.shared.updateAccount(account: account)
                    showAutoHiddenHud(style: .notification, text: Localized.TOAST_CHANGED)
                case let .failure(error):
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            }
        } else {
            UserAPI.shared.remarkFriend(userId: user.userId, full_name: newName) { [weak self](result) in
                self?.handlerUpdateUser(result)
            }
        }
    }
    
    private func transactionsAction() {
        UIApplication.homeNavigationController?.pushViewController(PeerTransactionsViewController.instance(opponentId: user.userId), animated: true)
    }

    private func unblockAction() {
        showLoading()
        UserAPI.shared.unblockUser(userId: user.userId) { [weak self] (result) in
            self?.handlerUpdateUser(result)
        }
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
                showAutoHiddenHud(style: .notification, text: toastMessage)
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }

    private func editName() {
        editAliasNameController.textFields?.first?.text = user.fullName
        UIApplication.currentActivity()?.present(editAliasNameController, animated: true, completion: nil)
    }

    private func editBiography() {
        UIApplication.homeNavigationController?.pushViewController(BiographyViewController.instance(user: user), animated: true)
    }

    private func removeAction() {
        showLoading()
        UserAPI.shared.removeFriend(userId: user.userId, completion: { [weak self](result) in
            self?.handlerUpdateUser(result, notifyContact: true)
        })
    }

    private func handlerUpdateUser(_ result: APIResult<UserResponse>, showError: Bool = true, notifyContact: Bool = false, completion: (() -> Void)? = nil) {
        switch result {
        case let .success(user):
            UserDAO.shared.updateUsers(users: [user], notifyContact: notifyContact)
            updateUser(user: UserItem.createUser(from: user), animated: true, refreshUser: false, superView: superView)
        case let .failure(error):
            if showError {
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
        completion?()
    }
    
    private func clearChatAction() {
        let conversationId = ConversationDAO.shared.makeConversationId(userId: AccountAPI.shared.accountUserId, ownerUserId: user.userId)
        DispatchQueue.global().async {
            MessageDAO.shared.clearChat(conversationId: conversationId)
            DispatchQueue.main.async {
                showAutoHiddenHud(style: .notification, text: Localized.GROUP_CLEAR_SUCCESS)
            }
        }
    }
    
    @IBAction func sendAction(_ sender: Any) {
        superView?.dismissPopupControllerAnimated()
        if let conversationVC = UIApplication.homeNavigationController?.viewControllers.last as? ConversationViewController, conversationVC.dataSource?.category == ConversationDataSource.Category.contact && conversationVC.dataSource?.conversation.ownerId == user.userId {
            return
        }

        UIApplication.homeNavigationController?.pushViewController(withBackRoot: ConversationViewController.instance(ownerUser: user))
    }
    
    @IBAction func addAction(_ sender: Any) {
        guard !addContactButton.isBusy else {
            return
        }
        addContactButton.isBusy = true
        UserAPI.shared.addFriend(userId: user.userId, full_name: user.fullName, completion: { [weak self] (result) in
            self?.handlerUpdateUser(result, notifyContact: true, completion: {
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
            self?.handlerUpdateUser(result, notifyContact: true, completion: {
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
        guard let parent = UIApplication.homeNavigationController?.visibleViewController else {
            return
        }
        guard !openUrlOutsideApplication(url) else {
            return
        }
        dismissAction(self)
        if !UrlWindow.checkUrl(url: url) {
            WebViewController.presentInstance(with: .init(conversationId: conversationId, initialUrl: url), asChildOf: parent)
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
    
    class MenuDismissResponder: UIButton {
        
        convenience init() {
            let frame = AppDelegate.current.window.bounds
            self.init(frame: frame)
            backgroundColor = .clear
            addTarget(self, action: #selector(dismissMenu), for: .touchUpInside)
        }
        
        @objc func dismissMenu() {
            UIMenuController.shared.setMenuVisible(false, animated: true)
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
        let hud = self.hud
        hud.show(style: .busy, text: "", on: AppDelegate.current.window)
        AccountAPI.shared.update(fullName: nil, avatarBase64: avatarBase64, completion: { (result) in
            switch result {
            case let .success(account):
                AccountAPI.shared.updateAccount(account: account)
                hud.set(style: .notification, text: Localized.TOAST_CHANGED)
            case let .failure(error):
                hud.set(style: .error, text: error.localizedDescription)
            }
            hud.scheduleAutoHidden()
        })
    }

}

extension UserView: UIGestureRecognizerDelegate {
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == longPressRecognizer else {
            return true
        }
        let location = gestureRecognizer.location(in: self)
        let area = idLabel.convert(idLabel.bounds, to: self).insetBy(dx: -8, dy: -8)
        return area.contains(location)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
}
