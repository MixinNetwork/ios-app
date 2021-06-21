import UIKit
import MixinServices

final class UserProfileViewController: ProfileViewController {
    
    var updateUserFromRemoteAfterReloaded = true
    
    override var conversationId: String {
        return ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: user.userId)
    }
    
    override var isMuted: Bool {
        return user.isMuted
    }

    override var conversationName: String {
        return user.fullName
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    var user: UserItem! {
        didSet {
            isMe = user.userId == myUserId
            relationship = Relationship(rawValue: user.relationship) ?? .ME
            updateDeveloper()
        }
    }
    
    private lazy var imagePicker = ImagePickerController(initialCameraPosition: .front, cropImageAfterPicked: true, parent: self, delegate: self)
    private lazy var footerLabel = FooterLabel()
    
    private var isMe = false
    private var relationship = Relationship.ME
    private var developer: UserItem?
    private var avatarPreviewImageView: UIImageView?
    private var avatarPreviewBackgroundView: UIVisualEffectView?
    private var favoriteAppMenuItemViewIfLoaded: MyFavoriteAppProfileMenuItemView?
    private var favoriteAppViewIfLoaded: ProfileFavoriteAppsView?
    private var sharedAppUsers: [User]?
    private var dismissHomeAppsWindow = true
    
    init(user: UserItem) {
        super.init(nibName: R.nib.profileView.name, bundle: R.nib.profileView.bundle)
        modalPresentationStyle = .custom
        transitioningDelegate = PopupPresentationManager.shared
        defer {
            // Defer closure escapes from subclass init
            // Make sure user's didSet is called
            self.user = user
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if dismissHomeAppsWindow {
            UIApplication.homeViewController?.dismissAppsWindow()
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        size = isMe ? .unavailable : .compressed
        super.viewDidLoad()
        reloadData()
        reloadFavoriteApps(userId: user.userId, fromRemote: true)
        if !isMe {
            reloadCircles(conversationId: conversationId, userId: user.userId)
        }
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction(_:)))
        recognizer.delegate = self
        view.addGestureRecognizer(recognizer)
        NotificationCenter.default.addObserver(self, selector: #selector(willHideMenu(_:)), name: UIMenuController.willHideMenuNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(accountDidChange(_:)), name: LoginManager.accountDidChangeNotification, object: nil)
    }

    override func dismissAction(_ sender: Any) {
        dismissHomeAppsWindow = false
        super.dismissAction(sender)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let coordinator = transitionCoordinator, let imageView = avatarPreviewImageView, let backgroundView = avatarPreviewBackgroundView {
            coordinator.animate(alongsideTransition: { (context) in
                imageView.frame.origin.y = AppDelegate.current.mainWindow.bounds.height
                backgroundView.effect = nil
                for view in backgroundView.contentView.subviews {
                    view.alpha = 0
                }
            }) { (_) in
                backgroundView.removeFromSuperview()
            }
        }
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return action == #selector(copy(_:))
    }
    
    override func copy(_ sender: Any?) {
        UIPasteboard.general.string = user.identityNumber
    }
    
    override func previewAvatarAction(_ sender: Any) {
        guard let image = avatarImageView.image else {
            return
        }
        let window = AppDelegate.current.mainWindow
        let initialFrame = avatarImageView.convert(avatarImageView.bounds, to: window)
    
        let backgroundView = UIVisualEffectView(effect: nil)
        backgroundView.frame = window.bounds
        backgroundView.isUserInteractionEnabled = false
        window.addSubview(backgroundView)
        avatarPreviewBackgroundView = backgroundView
             
        let dismissButton = UIButton()
        dismissButton.tintColor = R.color.icon_tint()
        dismissButton.setImage(R.image.ic_title_close(), for: .normal)
        dismissButton.isUserInteractionEnabled = false
        dismissButton.alpha = 0
        backgroundView.contentView.addSubview(dismissButton)
        dismissButton.snp.makeConstraints { (make) in
            make.width.height.equalTo(24)
            make.top.equalTo(window.safeAreaInsets.top + 10)
            make.left.equalTo(20)
        }
        
        let imageView = UIImageView(frame: initialFrame)
        imageView.layer.cornerRadius = initialFrame.height / 2
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        imageView.image = image
        imageView.alpha = 0
        backgroundView.contentView.addSubview(imageView)
        avatarPreviewImageView = imageView
        view.isUserInteractionEnabled = false
        hideContentConstraint.priority = .defaultHigh
        UIView.animate(withDuration: 0.5, animations: {
            UIView.setAnimationCurve(.overdamped)
            self.view.layoutIfNeeded()
            let width = window.bounds.width - 28 * 2
            imageView.bounds = CGRect(x: 0, y: 0, width: width, height: width)
            imageView.center = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
            imageView.layer.cornerRadius = width / 2
            backgroundView.effect = .regularBlur
            dismissButton.alpha = 1
            imageView.alpha = 1
        })
    }
    
    override func updateMuteInterval(inSeconds interval: Int64) {
        let userId = user.userId
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        let conversationRequest = ConversationRequest(conversationId: conversationId, name: nil, category: ConversationCategory.CONTACT.rawValue, participants: [ParticipantRequest(userId: userId, role: "")], duration: interval, announcement: nil)
        ConversationAPI.mute(conversationId: conversationId, conversationRequest: conversationRequest) { [weak self] (result) in
            switch result {
            case let .success(response):
                DispatchQueue.global().async {
                    UserDAO.shared.updateUser(with: userId, muteUntil: response.muteUntil)
                }
                if let self = self {
                    self.user.muteUntil = response.muteUntil
                    self.reloadData()
                }
                let toastMessage: String
                if interval == MuteInterval.none {
                    toastMessage = Localized.PROFILE_TOAST_UNMUTED
                } else {
                    let dateRepresentation = DateFormatter.dateSimple.string(from: response.muteUntil.toUTCDate())
                    toastMessage = Localized.PROFILE_TOAST_MUTED(muteUntil: dateRepresentation)
                }
                hud.set(style: .notification, text: toastMessage)
            case let .failure(error):
                hud.set(style: .error, text: error.localizedDescription)
            }
            hud.scheduleAutoHidden()
        }
    }
    
    @objc func willHideMenu(_ notification: Notification) {
        subtitleLabel.highlightIdentityNumber = false
    }
    
    @objc func accountDidChange(_ notification: Notification) {
        guard let account = LoginManager.shared.account, account.user_id == user.userId else {
            return
        }
        self.user = UserItem.createUser(from: account)
        reloadData()
    }
    
    @objc func longPressAction(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else {
            return
        }
        becomeFirstResponder()
        subtitleLabel.highlightIdentityNumber = true
        if let highlightedRect = subtitleLabel.highlightedRect {
            let menu = UIMenuController.shared
            menu.setTargetRect(highlightedRect, in: subtitleLabel)
            menu.setMenuVisible(true, animated: true)
            AppDelegate.current.mainWindow.addDismissMenuResponder()
        }
    }
    
}

// MARK: - UIGestureRecognizerDelegate
extension UserProfileViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let location = gestureRecognizer.location(in: view)
        let area = subtitleLabel.convert(subtitleLabel.bounds, to: view).insetBy(dx: -8, dy: -8)
        return area.contains(location)
    }
    
}

// MARK: - ImagePickerControllerDelegate
extension UserProfileViewController: ImagePickerControllerDelegate {
    
    func imagePickerController(_ controller: ImagePickerController, didPickImage image: UIImage) {
        guard let avatarBase64 = image.imageByScaling(to: CGSize(width: 1024, height: 1024))?.base64 else {
            alert(Localized.CONTACT_ERROR_COMPOSE_AVATAR)
            return
        }
        let hud = Hud()
        hud.show(style: .busy, text: "", on: view)
        AccountAPI.update(fullName: nil, avatarBase64: avatarBase64, completion: { (result) in
            switch result {
            case let .success(account):
                LoginManager.shared.setAccount(account)
                hud.set(style: .notification, text: Localized.TOAST_CHANGED)
            case let .failure(error):
                hud.set(style: .error, text: error.localizedDescription)
            }
            hud.scheduleAutoHidden()
        })
    }
    
}

// MARK: - Actions
extension UserProfileViewController {
    
    @objc func showFavoriteApps() {
        guard let users = sharedAppUsers else {
            return
        }
        let vc = R.storyboard.contact.shared_apps()!
        vc.transitioningDelegate = PopupPresentationManager.shared
        vc.modalPresentationStyle = .custom
        vc.loadViewIfNeeded()
        vc.titleLabel.text = R.string.localizable.profile_shared_app_of_user(user.fullName)
        vc.users = users
        dismissAndPresent(vc)
    }
    
    @objc func editFavoriteApps() {
        let vc = EditSharedAppsViewController.instance()
        dismissAndPush(vc)
    }
    
    @objc func addContact() {
        relationshipView.isBusy = true
        UserAPI.addFriend(userId: user.userId, full_name: user.fullName) { [weak self] (result) in
            switch result {
            case let .success(response):
                self?.handle(userResponse: response, postContactDidChangeNotificationOnSuccess: true)
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
            self?.relationshipView.isBusy = false
        }
    }
    
    @objc func sendMessage() {
        guard let navigationController = UIApplication.homeNavigationController else {
            return
        }
        if let vc = navigationController.viewControllers.last as? ConversationViewController, vc.dataSource?.category == .contact && vc.dataSource?.conversation.ownerId == user.userId {
            dismiss(animated: true, completion: nil)
            return
        }
        let vc = ConversationViewController.instance(ownerUser: user)
        dismiss(animated: true) {
            UIApplication.homeNavigationController?.pushViewController(withBackRoot: vc)
        }
    }
    
    @objc func showMyQrCode() {
        guard let account = LoginManager.shared.account else {
            return
        }
        let window = QrcodeWindow.instance()
        window.render(title: Localized.CONTACT_MY_QR_CODE,
                      description: Localized.MYQRCODE_PROMPT,
                      account: account)
        window.presentPopupControllerAnimated()
    }
    
    @objc func showMyMoneyReceivingCode() {
        guard let account = LoginManager.shared.account else {
            return
        }
        let window = QrcodeWindow.instance()
        window.renderMoneyReceivingCode(account: account)
        window.presentPopupControllerAnimated()
    }
    
    @objc func changeAvatarWithCamera() {
        imagePicker.presentCamera()
    }
    
    @objc func changeAvatarWithLibrary() {
        imagePicker.presentPhoto()
    }
    
    @objc func editMyName() {
        presentEditNameController(title: R.string.localizable.profile_edit_name(), text: user.fullName, placeholder: R.string.localizable.profile_full_name()) { (name) in
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            AccountAPI.update(fullName: name) { (result) in
                switch result {
                case let .success(account):
                    LoginManager.shared.setAccount(account)
                    hud.set(style: .notification, text: Localized.TOAST_CHANGED)
                case let .failure(error):
                    hud.set(style: .error, text: error.localizedDescription)
                }
                hud.scheduleAutoHidden()
            }
        }
    }
    
    @objc func editMyBiography() {
        let vc = BiographyViewController.instance(user: user)
        dismissAndPush(vc)
    }
    
    @objc func changeNumber() {
        if LoginManager.shared.account?.has_pin ?? false {
            let vc = VerifyPinNavigationController(rootViewController: ChangeNumberVerifyPinViewController())
            dismissAndPresent(vc)
        } else {
            let vc = WalletPasswordViewController.instance(dismissTarget: .changePhone)
            dismissAndPush(vc)
        }
    }
    
    @objc func openApp() {
        let userId = user.userId
        dismiss(animated: true) {
            guard let parent = UIApplication.homeNavigationController?.visibleViewController else {
                return
            }
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
                DispatchQueue.main.async {
                    AppGroupUserDefaults.User.insertRecentlyUsedAppId(id: app.appId)
                    MixinWebViewController.presentInstance(with: .init(conversationId: conversationId, app: app), asChildOf: parent)
                }
                reporter.report(event: .openApp, userInfo: ["source": "UserWindow", "identityNumber": app.appNumber])
            }
        }
    }
    
    @objc func transfer() {
        let viewController: UIViewController
        if LoginManager.shared.account?.has_pin ?? false {
            viewController = TransferOutViewController.instance(asset: nil, type: .contact(user))
        } else {
            viewController = WalletPasswordViewController.instance(dismissTarget: .transfer(user: user))
        }
        dismissAndPush(viewController)
    }
    
    @objc func editAlias() {
        let userId = user.userId
        presentEditNameController(title: R.string.localizable.profile_edit_name(), text: user.fullName, placeholder: R.string.localizable.profile_full_name()) { [weak self] (name) in
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            UserAPI.remarkFriend(userId: userId, full_name: name) { [weak self] (result) in
                switch result {
                case let .success(response):
                    self?.handle(userResponse: response, postContactDidChangeNotificationOnSuccess: false)
                    hud.set(style: .notification, text: Localized.TOAST_CHANGED)
                case let .failure(error):
                    hud.set(style: .error, text: error.localizedDescription)
                }
                hud.scheduleAutoHidden()
            }
        }
    }
    
    @objc func showDeveloper() {
        guard let developer = developer else {
            return
        }
        let vc = UserProfileViewController(user: user)
        if user.appCreatorId == myUserId, let account = LoginManager.shared.account {
            vc.user = UserItem.createUser(from: account)
        } else {
            vc.user = developer
        }
        dismissAndPresent(vc)
    }
    
    @objc func shareUser() {
        let vc = MessageReceiverViewController.instance(content: .contact(user.userId))
        dismissAndPush(vc)
    }
    
    @objc func searchConversation() {
        let vc = InConversationSearchViewController()
        vc.load(user: user, conversationId: conversationId)
        let container = ContainerViewController.instance(viewController: vc, title: user.fullName)
        dismissAndPush(container)
    }
    
    @objc func showSharedMedia() {
        let vc = R.storyboard.chat.shared_media()!
        vc.conversationId = conversationId
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.chat_shared_media())
        dismissAndPush(container)
    }
    
    @objc func showTransactions() {
        let vc = PeerTransactionsViewController.instance(opponentId: user.userId)
        dismissAndPush(vc)
    }
    
    @objc func callWithMixin() {
        let user = self.user!
        dismiss(animated: true) {
            CallService.shared.requestStartPeerToPeerCall(remoteUser: user)
        }
    }

    @objc func callPhone() {
        guard let phone = user.phone, !phone.isEmpty, let url = URL(string: "tel://" + phone) else {
            return
        }
        UIApplication.shared.openURL(url: url)
    }
    
    @objc func removeFriend() {
        let userId = user.userId
        let hint = user.isBot ? R.string.localizable.profile_remove_hint_bot() : R.string.localizable.profile_remove_hint_contact()
        let removeTitle = user.isBot ? R.string.localizable.profile_remove_bot() : R.string.localizable.profile_remove_contact()
        let alert = UIAlertController(title: hint, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: removeTitle, style: .destructive, handler: { (_) in
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            UserAPI.removeFriend(userId: userId, completion: { [weak self] (result) in
                switch result {
                case let .success(response):
                    self?.handle(userResponse: response, postContactDidChangeNotificationOnSuccess: true)
                    hud.set(style: .notification, text: R.string.localizable.toast_deleted())
                case let .failure(error):
                    hud.set(style: .error, text: error.localizedDescription)
                }
                hud.scheduleAutoHidden()
            })
        }))
        present(alert, animated: true, completion: nil)
    }
    
    @objc func blockUser() {
        let userId = user.userId
        let alert = UIAlertController(title: R.string.localizable.profile_block_hint(), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.profile_block(), style: .destructive, handler: { (_) in
            self.relationshipView.isBusy = true
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            UserAPI.blockUser(userId: userId) { [weak self] (result) in
                switch result {
                case let .success(response):
                    self?.handle(userResponse: response, postContactDidChangeNotificationOnSuccess: false)
                    hud.set(style: .notification, text: R.string.localizable.toast_blocked())
                case let .failure(error):
                    hud.set(style: .error, text: error.localizedDescription)
                }
                hud.scheduleAutoHidden()
                self?.relationshipView.isBusy = false
            }
        }))
        present(alert, animated: true, completion: nil)
    }
    
    @objc func unblockUser() {
        relationshipView.isBusy = true
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        UserAPI.unblockUser(userId: user.userId) { [weak self] (result) in
            switch result {
            case let .success(response):
                self?.handle(userResponse: response, postContactDidChangeNotificationOnSuccess: false)
                hud.set(style: .notification, text: Localized.TOAST_CHANGED)
            case let .failure(error):
                hud.set(style: .error, text: error.localizedDescription)
            }
            hud.scheduleAutoHidden()
            self?.relationshipView.isBusy = false
        }
    }
    
    @objc func reportUser() {
        let userId = user.userId
        let alert = UIAlertController(title: R.string.localizable.profile_report_hint(), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.profile_report(), style: .destructive, handler: { (_) in
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            DispatchQueue.global().async {
                switch UserAPI.reportUser(userId: userId) {
                case let .success(user):
                    UserDAO.shared.updateUsers(users: [user], sendNotificationAfterFinished: false)
                    DispatchQueue.main.async {
                        hud.set(style: .notification, text: R.string.localizable.profile_report_success())
                        hud.scheduleAutoHidden()
                        self.dismiss(animated: true, completion: nil)
                    }
                case let .failure(error):
                    DispatchQueue.main.async {
                        hud.set(style: .error, text: error.localizedDescription)
                        hud.scheduleAutoHidden()
                    }
                }
            }
        }))
        present(alert, animated: true, completion: nil)
    }
    
}

// MARK: - Private works
extension UserProfileViewController {
    
    class FooterLabel: UILabel {
        
        convenience init() {
            let frame = CGRect(x: 0, y: 0, width: 414, height: 46)
            self.init(frame: frame)
            backgroundColor = .clear
            textColor = .accessoryText
            font = .preferredFont(forTextStyle: .footnote)
            adjustsFontForContentSizeCategory = true
            numberOfLines = 0
            textAlignment = .center
        }
        
        override var intrinsicContentSize: CGSize {
            let size = super.intrinsicContentSize
            return CGSize(width: size.width, height: size.height + 30)
        }
        
    }
    
    private func reloadData() {
        for view in centerStackView.subviews {
            view.removeFromSuperview()
        }
        for view in menuStackView.subviews {
            view.removeFromSuperview()
        }
        
        avatarImageView.setImage(with: user)
        titleLabel.text = user.fullName
        subtitleLabel.identityNumber = user.identityNumber
        
        if user.isVerified {
            badgeImageView.image = R.image.ic_user_verified()
            badgeImageView.isHidden = false
        } else if user.isBot {
            badgeImageView.image = R.image.ic_user_bot()
            badgeImageView.isHidden = false
        } else {
            badgeImageView.isHidden = true
        }
        
        switch relationship {
        case .ME, .FRIEND:
            relationshipView.style = .none
        case .STRANGER:
            if user.isBot {
                relationshipView.style = .addBot
            } else {
                relationshipView.style = .addContact
            }
            relationshipView.button.removeTarget(nil, action: nil, for: .allEvents)
            relationshipView.button.addTarget(self, action: #selector(addContact), for: .touchUpInside)
            centerStackView.addArrangedSubview(relationshipView)
        case .BLOCKING:
            relationshipView.style = .unblock
            relationshipView.button.removeTarget(nil, action: nil, for: .allEvents)
            relationshipView.button.addTarget(self, action: #selector(unblockUser), for: .touchUpInside)
            centerStackView.addArrangedSubview(relationshipView)
        }
        
        if !user.biography.isEmpty {
            descriptionView.label.text = user.biography
            centerStackView.addArrangedSubview(descriptionView)
        }
        
        if !isMe {
            if let view = favoriteAppViewIfLoaded {
                centerStackView.addArrangedSubview(view)
            }
            
            if user.isBot {
                shortcutView.leftShortcutButton.setImage(R.image.ic_open_app(), for: .normal)
                shortcutView.leftShortcutButton.removeTarget(nil, action: nil, for: .allEvents)
                shortcutView.leftShortcutButton.addTarget(self, action: #selector(openApp), for: .touchUpInside)
            } else {
                shortcutView.leftShortcutButton.setImage(R.image.ic_transfer(), for: .normal)
                shortcutView.leftShortcutButton.removeTarget(nil, action: nil, for: .allEvents)
                shortcutView.leftShortcutButton.addTarget(self, action: #selector(transfer), for: .touchUpInside)
            }
            shortcutView.sendMessageButton.removeTarget(nil, action: nil, for: .allEvents)
            shortcutView.sendMessageButton.addTarget(self, action: #selector(sendMessage), for: .touchUpInside)
            shortcutView.toggleSizeButton.removeTarget(nil, action: nil, for: .allEvents)
            shortcutView.toggleSizeButton.addTarget(self, action: #selector(toggleSize), for: .touchUpInside)
            centerStackView.addArrangedSubview(shortcutView)
        }
        
        if isMe || centerStackView.arrangedSubviews.isEmpty {
            menuStackViewTopConstraint.constant = 24
        } else {
            menuStackViewTopConstraint.constant = 0
        }
        
        if isMe {
            let groups = [
                [ProfileMenuItem(title: R.string.localizable.profile_my_qrcode(),
                                 subtitle: nil,
                                 style: [],
                                 action: #selector(showMyQrCode)),
                 ProfileMenuItem(title: R.string.localizable.contact_receive_money(),
                                 subtitle: nil,
                                 style: [],
                                 action: #selector(showMyMoneyReceivingCode))],
                [ProfileMenuItem(title: R.string.localizable.profile_edit_name(),
                                 subtitle: nil,
                                 style: [],
                                 action: #selector(editMyName)),
                 ProfileMenuItem(title: R.string.localizable.profile_edit_biography(),
                                 subtitle: nil,
                                 style: [],
                                 action: #selector(editMyBiography))],
                [ProfileMenuItem(title: R.string.localizable.profile_change_avatar_camera(),
                                 subtitle: nil,
                                 style: [],
                                 action: #selector(changeAvatarWithCamera)),
                 ProfileMenuItem(title: R.string.localizable.profile_change_avatar_library(),
                                 subtitle: nil,
                                 style: [],
                                 action: #selector(changeAvatarWithLibrary))],
                [ProfileMenuItem(title: R.string.localizable.profile_change_number(),
                                 subtitle: user.phone,
                                 style: [],
                                 action: #selector(changeNumber))]
            ]
            reloadMenu(groups: groups)
            
            if favoriteAppMenuItemViewIfLoaded == nil {
                let view = MyFavoriteAppProfileMenuItemView()
                view.avatarStackView.iconLength = 27
                view.button.addTarget(self, action: #selector(editFavoriteApps), for: .touchUpInside)
                menuStackView.insertArrangedSubview(view, at: 0)
                favoriteAppMenuItemViewIfLoaded = view
            }
            menuStackView.insertArrangedSubview(favoriteAppMenuItemViewIfLoaded!, at: 0)
            
            if let createdAt = user.createdAt?.toUTCDate() {
                let rep = DateFormatter.dateSimple.string(from: createdAt)
                footerLabel.text = R.string.localizable.profile_join_in(rep)
                menuStackView.addArrangedSubview(footerLabel)
            }
        } else {
            var groups = [[ProfileMenuItem]]()
            
            let shareUserItem = ProfileMenuItem(title: R.string.localizable.profile_share_card(),
                                                subtitle: nil,
                                                style: [],
                                                action: #selector(shareUser))
            groups.append([shareUserItem])
            
            let sharedMediaAndSearchGroup = [
                ProfileMenuItem(title: R.string.localizable.chat_shared_media(),
                                subtitle: nil,
                                style: [],
                                action: #selector(showSharedMedia)),
                ProfileMenuItem(title: R.string.localizable.profile_search_conversation(),
                                subtitle: nil,
                                style: [],
                                action: #selector(searchConversation))
            ]
            groups.append(sharedMediaAndSearchGroup)
            
            let muteAndTransactionGroup: [ProfileMenuItem] = {
                var group: [ProfileMenuItem]
                if user.isMuted {
                    let subtitle: String?
                    if let date = user.muteUntil?.toUTCDate() {
                        let rep = DateFormatter.log.string(from: date)
                        subtitle = R.string.localizable.profile_mute_ends_at(rep)
                    } else {
                        subtitle = nil
                    }
                    group = [ProfileMenuItem(title: R.string.localizable.profile_muted(),
                                             subtitle: subtitle,
                                             style: [],
                                             action: #selector(mute))]
                } else {
                    group = [ProfileMenuItem(title: R.string.localizable.profile_mute(),
                                             subtitle: nil,
                                             style: [],
                                             action: #selector(mute))]
                }
                if relationship == .FRIEND {
                    group.append(ProfileMenuItem(title: R.string.localizable.profile_edit_name(),
                                                 subtitle: nil,
                                                 style: [],
                                                 action: #selector(editAlias)))
                }
                return group
            }()
            groups.append(muteAndTransactionGroup)

            if !user.isBot {
                let callGroup: [ProfileMenuItem] = {
                    var group = [ProfileMenuItem(title: R.string.localizable.profile_call_with_mixin(),
                                                 subtitle: nil,
                                                 style: [],
                                                 action: #selector(callWithMixin))]
                    if let number = user.phone, !number.isEmpty {
                        group.append(ProfileMenuItem(title: R.string.localizable.profile_call_phone(),
                                                     subtitle: number,
                                                     style: [],
                                                     action: #selector(callPhone)))
                    }
                    return group
                }()
                groups.append(callGroup)
            }
            
            let editAliasAndBotRelatedGroup: [ProfileMenuItem] = {
                var group = [ProfileMenuItem]()
                if user.isBot && !user.isSelfBot {
                    group.append(ProfileMenuItem(title: R.string.localizable.chat_menu_developer(),
                                                 subtitle: nil,
                                                 style: [],
                                                 action: #selector(showDeveloper)))
                }
                group.append(ProfileMenuItem(title: R.string.localizable.profile_transactions(),
                                             subtitle: nil,
                                             style: [],
                                             action: #selector(showTransactions)))
                return group
            }()
            if !editAliasAndBotRelatedGroup.isEmpty {
                groups.append(editAliasAndBotRelatedGroup)
            }
            
            let contactRelationshipGroup: [ProfileMenuItem] = {
                var group: [ProfileMenuItem]
                switch relationship {
                case .ME:
                    group = []
                case .FRIEND:
                    let removeTitle = user.isBot ? R.string.localizable.profile_remove_bot() : R.string.localizable.profile_remove_contact()
                    group = [ProfileMenuItem(title: removeTitle,
                                             subtitle: nil,
                                             style: [.destructive],
                                             action: #selector(removeFriend))]
                case .STRANGER:
                    group = [ProfileMenuItem(title: R.string.localizable.profile_block(),
                                             subtitle: nil,
                                             style: [.destructive],
                                             action: #selector(blockUser))]
                case .BLOCKING:
                    group = [ProfileMenuItem(title: R.string.localizable.profile_unblock(),
                                             subtitle: nil,
                                             style: [.destructive],
                                             action: #selector(unblockUser))]
                }
                group.append(ProfileMenuItem(title: R.string.localizable.group_menu_clear(),
                                             subtitle: nil,
                                             style: [.destructive],
                                             action: #selector(clearChat)))
                return group
            }()
            groups.append(contactRelationshipGroup)
            
            let reportItem = ProfileMenuItem(title: R.string.localizable.profile_report(),
                                             subtitle: nil,
                                             style: [.destructive],
                                             action: #selector(reportUser))
            groups.append([reportItem])
            
            reloadMenu(groups: groups)
            menuStackView.insertArrangedSubview(circleItemView, at: groups.count - 2)
        }
        
        view.frame.size.width = AppDelegate.current.mainWindow.bounds.width
        updatePreferredContentSizeHeight(size: size)
        
        if updateUserFromRemoteAfterReloaded {
            updateUserFromRemoteAfterReloaded = false
            UserAPI.showUser(userId: user.userId) { [weak self] (result) in
                guard case let .success(response) = result else {
                    return
                }
                self?.handle(userResponse: response, postContactDidChangeNotificationOnSuccess: false)
            }
        }
    }
    
    private func reloadFavoriteApps(userId: String, fromRemote: Bool) {
        DispatchQueue.global().async { [weak self] in
            let users = FavoriteAppsDAO.shared.favoriteAppUsersOfUser(withId: userId)
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.sharedAppUsers = users
                weakSelf.updateFavoriteAppView(users: users)
                guard fromRemote else {
                    return
                }
                UserAPI.getFavoriteApps(ofUserWith: userId) { (result) in
                    guard case let .success(favApps) = result else {
                        return
                    }
                    DispatchQueue.global().async {
                        FavoriteAppsDAO.shared.updateFavoriteApps(favApps, forUserWith: userId)
                        let appUserIds = favApps.map({ $0.appId })
                        UserAPI.showUsers(userIds: appUserIds) { (result) in
                            guard case let .success(users) = result else {
                                return
                            }
                            UserDAO.shared.updateUsers(users: users)
                            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                                self?.reloadFavoriteApps(userId: userId, fromRemote: false)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func handle(userResponse: UserResponse, postContactDidChangeNotificationOnSuccess: Bool) {
        user = UserItem.createUser(from: userResponse)
        if let animator = sizeAnimator {
            animator.addCompletion { _ in
                self.reloadData()
            }
        } else {
            reloadData()
        }
        UserDAO.shared.updateUsers(users: [userResponse], notifyContact: postContactDidChangeNotificationOnSuccess)
    }
    
    private func updateDeveloper() {
        guard let creatorId = user.appCreatorId else {
            developer = nil
            return
        }
        DispatchQueue.global().async { [weak self] in
            var developer = UserDAO.shared.getUser(userId: creatorId)
            if developer == nil {
                switch UserAPI.showUser(userId: creatorId) {
                case let .success(user):
                    UserDAO.shared.updateUsers(users: [user], sendNotificationAfterFinished: false)
                    developer = UserItem.createUser(from: user)
                case let .failure(error):
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            }
            self?.developer = developer
        }
    }
    
    private func updateFavoriteAppView(users: [User]) {
        if isMe {
            favoriteAppMenuItemViewIfLoaded?.avatarStackView.users = users
        } else {
            if users.isEmpty {
                favoriteAppViewIfLoaded?.removeFromSuperview()
                favoriteAppViewIfLoaded = nil
            } else {
                if favoriteAppViewIfLoaded == nil {
                    let view = R.nib.profileFavoriteAppsView(owner: nil)!
                    view.button.addTarget(self, action: #selector(showFavoriteApps), for: .touchUpInside)
                    if let shortcut = shortcutViewIfLoaded, let index = centerStackView.arrangedSubviews.firstIndex(of: shortcut) {
                        centerStackView.insertArrangedSubview(view, at: index)
                    } else {
                        centerStackView.addArrangedSubview(view)
                    }
                    favoriteAppViewIfLoaded = view
                }
                favoriteAppViewIfLoaded?.avatarStackView.users = users
            }
            view.layoutIfNeeded()
            updatePreferredContentSizeHeight(size: size)
        }
    }
    
}
