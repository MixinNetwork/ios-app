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
    
    private lazy var deactivatedHintView = R.nib.accountDeactivatedHintView(withOwner: nil)!
    private lazy var imagePicker = ImagePickerController(initialCameraPosition: .front, cropImageAfterPicked: true, parent: self, delegate: self)
    private lazy var footerLabel = FooterLabel()
    private lazy var expiredMessageItemView: ProfileMenuItemView  = {
        let view = ProfileMenuItemView()
        view.label.text = R.string.localizable.disappearing_message()
        view.subtitleLabel.text = ""
        view.button.addTarget(self, action: #selector(self.editExpiredMessageDuration), for: .touchUpInside)
        return view
    }()
    
    private weak var membershipButton: UIButton?
    
    private var isMe = false
    private var relationship = Relationship.ME
    private var developer: UserItem?
    private var avatarPreviewImageView: UIImageView?
    private var avatarPreviewBackgroundView: UIVisualEffectView?
    private var favoriteAppMenuItemViewIfLoaded: MyFavoriteAppProfileMenuItemView?
    private var favoriteAppViewIfLoaded: ProfileFavoriteAppsView?
    private var sharedAppUsers: [User]?
    private var centerStackViewHeightConstraint: NSLayoutConstraint?
    private var conversationExpireIn: Int64?
    
    init(user: UserItem) {
        super.init(nibName: R.nib.profileView.name, bundle: R.nib.profileView.bundle)
        modalPresentationStyle = .custom
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
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
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        title = R.string.localizable.profile()
        size = isMe ? .unavailable : .compressed
        closeButton.isHidden = parent != nil
        titleViewHeightConstraint.constant = isMe ? 48 : 70
        super.viewDidLoad()
        reloadData()
        if user.isCreatedByMessenger {
            reloadFavoriteApps(userId: user.userId, fromRemote: true)
            if !isMe {
                reloadCircles(conversationId: conversationId, userId: user.userId)
                reloadMessageExpiration(conversationId: conversationId)
            }
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction(_:)))
            recognizer.delegate = self
            view.addGestureRecognizer(recognizer)
            NotificationCenter.default.addObserver(self, selector: #selector(willHideMenu(_:)), name: UIMenuController.willHideMenuNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(accountDidChange(_:)), name: LoginManager.accountDidChangeNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(favoriteAppsDidChange), name: FavoriteAppsDAO.favoriteAppsDidChangeNotification, object: nil)
        } else {
            resizeRecognizer.isEnabled = false
        }
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
        if parent != nil {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(dismissAvatarAction))
            backgroundView.addGestureRecognizer(recognizer)
        } else {
            backgroundView.isUserInteractionEnabled = false
            view.isUserInteractionEnabled = false
            hideContentConstraint.priority = .defaultHigh
        }
        UIView.animate(withDuration: 0.5, delay: 0, options: .overdampedCurve) {
            self.view.layoutIfNeeded()
            let width = window.bounds.width - 28 * 2
            imageView.bounds = CGRect(x: 0, y: 0, width: width, height: width)
            imageView.center = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
            imageView.layer.cornerRadius = width / 2
            backgroundView.effect = .regularBlur
            dismissButton.alpha = 1
            imageView.alpha = 1
        }
    }
    
    override func updateMuteInterval(inSeconds interval: Int64) {
        let userId = user.userId
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        let conversationRequest = ConversationRequest(conversationId: conversationId, name: nil, category: ConversationCategory.CONTACT.rawValue, participants: [ParticipantRequest(userId: userId, role: "")], duration: interval, announcement: nil, randomID: nil)
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
    
    @objc func willHideMenu(_ notification: Notification) {
        subtitleLabel.highlightIdentityNumber = false
    }
    
    @objc func accountDidChange(_ notification: Notification) {
        guard let account = LoginManager.shared.account, account.userID == user.userId else {
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
            AppDelegate.current.mainWindow.addDismissMenuResponder()
            UIMenuController.shared.showMenu(from: subtitleLabel, rect: highlightedRect)
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
        guard let avatarBase64 = image.imageByScaling(to: .avatar)?.asBase64Avatar() else {
            alert(R.string.localizable.failed_to_compose_avatar())
            return
        }
        let hud = Hud()
        hud.show(style: .busy, text: "", on: view)
        AccountAPI.update(fullName: nil, avatarBase64: avatarBase64, completion: { (result) in
            switch result {
            case let .success(account):
                LoginManager.shared.setAccount(account)
                hud.set(style: .notification, text: R.string.localizable.changed())
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
        vc.transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
        vc.modalPresentationStyle = .custom
        vc.loadViewIfNeeded()
        vc.titleLabel.text = R.string.localizable.contact_favorite_bots_title(user.fullName)
        vc.users = users
        dismissAndPresent(vc)
    }
    
    @objc func editFavoriteApps() {
        let vc = EditFavoriteAppsViewController()
        if parent != nil {
            navigationController?.pushViewController(vc, animated: true)
        } else {
            dismissAndPush(vc)
        }
    }
    
    @objc func addContact() {
        relationshipView.isBusy = true
        UserAPI.addFriend(userId: user.userId, fullName: user.fullName) { [weak self] (result) in
            switch result {
            case let .success(response):
                self?.handle(userResponse: response)
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
            checkedDismiss(animated: true)
            return
        }
        let vc = ConversationViewController.instance(ownerUser: user)
        checkedDismiss(animated: true) { _ in
            UIApplication.homeNavigationController?.pushViewController(withBackRoot: vc)
        }
    }
    
    @objc func changeAvatarWithCamera() {
        imagePicker.presentCamera()
    }
    
    @objc func changeAvatarWithLibrary() {
        imagePicker.presentPhoto()
    }
    
    @objc func editMyName() {
        presentEditNameController(title: R.string.localizable.edit_name(), text: user.fullName, placeholder: R.string.localizable.name()) { (name) in
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            AccountAPI.update(fullName: name) { (result) in
                switch result {
                case let .success(account):
                    LoginManager.shared.setAccount(account)
                    hud.set(style: .notification, text: R.string.localizable.changed())
                case let .failure(error):
                    hud.set(style: .error, text: error.localizedDescription)
                }
                hud.scheduleAutoHidden()
            }
        }
    }
    
    @objc func editMyBiography() {
        let vc = BiographyViewController(user: user)
        if parent != nil {
            navigationController?.pushViewController(vc, animated: true)
        } else {
            dismissAndPush(vc)
        }
    }
    
    @objc func changeNumber() {
        let verify = ChangeNumberPINValidationViewController()
        if let navigationController {
            navigationController.pushViewController(verify, animated: true)
        } else {
            dismissAndPush(verify)
        }
    }
    
    @objc func openApp() {
        let userId = user.userId
        checkedDismiss(animated: true) { _ in
            guard let container = UIApplication.homeContainerViewController else {
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
                    container.presentWebViewController(context: .init(conversationId: conversationId, app: app))
                }
            }
        }
    }
    
    @objc func transfer() {
        reporter.report(event: .sendStart, tags: ["wallet": "main", "source": "profile"])
        let user: UserItem = self.user
        let selector = MixinTokenSelectorViewController()
        selector.onSelected = { (token, location) in
            reporter.report(event: .sendTokenSelect, method: location.asEventMethod)
            reporter.report(event: .sendRecipient, tags: ["type": "contact"])
            let inputAmount = TransferInputAmountViewController(tokenItem: token, receiver: .user(user))
            UIApplication.homeNavigationController?.pushViewController(inputAmount, animated: true)
        }
        dismissAndPresent(selector)
    }
    
    @objc func editAlias() {
        let userId = user.userId
        presentEditNameController(title: R.string.localizable.edit_name(), text: user.fullName, placeholder: R.string.localizable.name()) { [weak self] (name) in
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            UserAPI.remarkFriend(userId: userId, full_name: name) { [weak self] (result) in
                switch result {
                case let .success(response):
                    self?.handle(userResponse: response)
                    hud.set(style: .notification, text: R.string.localizable.changed())
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
        vc.title = user.fullName
        dismissAndPush(vc)
    }
    
    @objc func showSharedMedia() {
        let vc = R.storyboard.chat.shared_media()!
        vc.conversationId = conversationId
        vc.title = R.string.localizable.shared_media()
        dismissAndPush(vc)
    }
    
    @objc func showTransactions() {
        let history = MixinTransactionHistoryViewController(user: user)
        dismissAndPush(history)
        reporter.report(event: .allTransactions, tags: ["source": "profile"])
    }
    
    @objc func groupsInCommon() {
        let vc = GroupsInCommonViewController.instance(userId: user.userId)
        dismissAndPush(vc)
    }
    
    @objc func callWithMixin() {
        let user = self.user!
        checkedDismiss(animated: true) { _ in
            CallService.shared.makePeerCall(with: user)
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
        let hint = user.isBot ? R.string.localizable.remove_bot_hint() : R.string.localizable.remove_contact_hint()
        let removeTitle = user.isBot ? R.string.localizable.remove_bot() : R.string.localizable.remove_contact()
        let alert = UIAlertController(title: hint, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: removeTitle, style: .destructive, handler: { (_) in
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            UserAPI.removeFriend(userId: userId, completion: { [weak self] (result) in
                switch result {
                case let .success(response):
                    self?.handle(userResponse: response)
                    hud.set(style: .notification, text: R.string.localizable.deleted())
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
        let alert = UIAlertController(title: R.string.localizable.block_hint(), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.block(), style: .destructive, handler: { (_) in
            self.relationshipView.isBusy = true
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            UserAPI.blockUser(userId: userId) { [weak self] (result) in
                switch result {
                case let .success(response):
                    self?.handle(userResponse: response)
                    hud.set(style: .notification, text: R.string.localizable.blocked())
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
                self?.handle(userResponse: response)
                hud.set(style: .notification, text: R.string.localizable.changed())
            case let .failure(error):
                hud.set(style: .error, text: error.localizedDescription)
            }
            hud.scheduleAutoHidden()
            self?.relationshipView.isBusy = false
        }
    }
    
    @objc func reportUser() {
        let userId = user.userId
        let alert = UIAlertController(title: R.string.localizable.report_and_block(), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.report(), style: .destructive, handler: { (_) in
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            DispatchQueue.global().async {
                switch UserAPI.reportUser(userId: userId) {
                case let .success(user):
                    UserDAO.shared.updateUsers(users: [user])
                    DispatchQueue.main.async {
                        hud.set(style: .notification, text: R.string.localizable.user_is_reported())
                        hud.scheduleAutoHidden()
                        self.presentingViewController?.dismiss(animated: true)
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
    
    @objc func editExpiredMessageDuration() {
        func dismissAndPushController(expireIn: Int64) {
            let controller = ExpiredMessageViewController(conversationId: conversationId, expireIn: expireIn)
            dismissAndPush(controller)
        }
        if let expireIn = conversationExpireIn {
            dismissAndPushController(expireIn: expireIn)
        } else {
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            let request = ConversationRequest(
                conversationId: conversationId,
                name: nil,
                category: ConversationCategory.CONTACT.rawValue,
                participants: [ParticipantRequest(userId: user.userId, role: "")],
                duration: nil,
                announcement: nil,
                randomID: nil
            )
            ConversationAPI.createConversation(conversation: request) { result in
                switch result {
                case let .success(response):
                    hud.hide()
                    dismissAndPushController(expireIn: response.expireIn)
                case let .failure(error):
                    hud.set(style: .error, text: error.localizedDescription)
                    hud.scheduleAutoHidden()
                }
            }
        }
    }
    
    @objc private func dismissAvatarAction() {
        guard let imageView = avatarPreviewImageView, let backgroundView = avatarPreviewBackgroundView else {
            return
        }
        UIView.animate(withDuration: 0.3) {
            imageView.frame.origin.y = AppDelegate.current.mainWindow.bounds.height
            backgroundView.effect = nil
            for view in backgroundView.contentView.subviews {
                view.alpha = 0
            }
        } completion: { _ in
            backgroundView.removeFromSuperview()
        }
    }
    
    @objc private func favoriteAppsDidChange() {
        reloadFavoriteApps(userId: user.userId, fromRemote: false)
    }
    
    @objc private func buyMembership(_ sender: Any) {
        guard let plan = user?.membership?.unexpiredPlan else {
            return
        }
        let buyingPlan = SafeMembership.Plan(userMembershipPlan: plan)
        let plans = MembershipPlansViewController(selectedPlan: buyingPlan)
        dismissAndPresent(plans)
    }
    
}

// MARK: - Private works
extension UserProfileViewController {
    
    class FooterLabel: UILabel {
        
        convenience init() {
            let frame = CGRect(x: 0, y: 0, width: 414, height: 46)
            self.init(frame: frame)
            backgroundColor = .clear
            textColor = R.color.text_tertiary()!
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
        let isMessengerUser = user.isCreatedByMessenger
        
        avatarImageView.setImage(with: user)
        titleLabel.text = user.fullName
        if isMessengerUser {
            subtitleLabel.identityNumber = user.identityNumber
        } else {
            subtitleLabel.identityNumber = nil
        }
        
        let badgeImage = user.badgeImage
        badgeImageView.image = badgeImage
        badgeImageView.isHidden = badgeImage == nil
        if user.membership?.unexpiredPlan == nil {
            membershipButton?.removeFromSuperview()
        } else if membershipButton == nil {
            let button = UIButton()
            button.addTarget(self, action: #selector(buyMembership(_:)), for: .touchUpInside)
            headerView.addSubview(button)
            button.snp.makeConstraints { make in
                make.width.height.equalTo(30)
                make.center.equalTo(badgeImageView)
            }
            membershipButton = button
        }
        
        if user.isDeactivated {
            centerStackView.addArrangedSubview(deactivatedHintView)
        } else if isMessengerUser {
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
        }
        
        if !user.biography.isEmpty {
            descriptionView.label.text = user.biography
            centerStackView.addArrangedSubview(descriptionView)
        }
        
        if !isMe, isMessengerUser {
            if let view = favoriteAppViewIfLoaded {
                centerStackView.addArrangedSubview(view)
            }
            
            shortcutView.leftShortcutButton.removeTarget(nil, action: nil, for: .allEvents)
            if user.isDeactivated {
                shortcutView.leftShortcutButton.setImage(R.image.ic_share(), for: .normal)
                shortcutView.leftShortcutButton.addTarget(self, action: #selector(shareUser), for: .touchUpInside)
            } else if user.isBot {
                shortcutView.leftShortcutButton.setImage(R.image.ic_open_app(), for: .normal)
                shortcutView.leftShortcutButton.addTarget(self, action: #selector(openApp), for: .touchUpInside)
            } else {
                shortcutView.leftShortcutButton.setImage(R.image.ic_transfer(), for: .normal)
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
        if !isMessengerUser && centerStackView.arrangedSubviews.isEmpty {
            if let constraint = centerStackViewHeightConstraint {
                constraint.isActive = true
            } else {
                let constraint = centerStackView.heightAnchor.constraint(equalToConstant: 38)
                constraint.isActive = true
                centerStackViewHeightConstraint = constraint
            }
        } else {
            centerStackViewHeightConstraint?.isActive = false
        }
        
        if isMe {
            let phoneTitle = if user.isAnonymous {
                R.string.localizable.add_mobile_number()
            } else {
                R.string.localizable.change_phone_number()
            }
            let groups = [
                [ProfileMenuItem(title: R.string.localizable.edit_name(),
                                 subtitle: nil,
                                 style: [],
                                 action: #selector(editMyName)),
                 ProfileMenuItem(title: R.string.localizable.edit_biography(),
                                 subtitle: nil,
                                 style: [],
                                 action: #selector(editMyBiography))],
                [ProfileMenuItem(title: R.string.localizable.change_profile_photo_with_camera(),
                                 subtitle: nil,
                                 style: [],
                                 action: #selector(changeAvatarWithCamera)),
                 ProfileMenuItem(title: R.string.localizable.change_profile_photo_with_library(),
                                 subtitle: nil,
                                 style: [],
                                 action: #selector(changeAvatarWithLibrary))],
                [ProfileMenuItem(title: phoneTitle,
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
                footerLabel.text = R.string.localizable.joined_in(rep)
                menuStackView.addArrangedSubview(footerLabel)
            }
        } else if isMessengerUser {
            var groups = [[ProfileMenuItem]]()
            
            let shareUserItem = ProfileMenuItem(title: R.string.localizable.share_contact(),
                                                subtitle: nil,
                                                style: [],
                                                action: #selector(shareUser))
            groups.append([shareUserItem])
            
            let sharedMediaAndSearchGroup = [
                ProfileMenuItem(title: R.string.localizable.shared_media(),
                                subtitle: nil,
                                style: [],
                                action: #selector(showSharedMedia)),
                ProfileMenuItem(title: R.string.localizable.search_conversation(),
                                subtitle: nil,
                                style: [],
                                action: #selector(searchConversation))
            ]
            groups.append(sharedMediaAndSearchGroup)
            let chatBackgroundGroup = [
                ProfileMenuItem(title: R.string.localizable.chat_background(),
                                subtitle: nil,
                                style: [],
                                action: #selector(changeChatBackground))
            ]
            groups.append(chatBackgroundGroup)
            
            let muteAndTransactionGroup: [ProfileMenuItem] = {
                var group: [ProfileMenuItem]
                if user.isMuted {
                    let subtitle: String?
                    if let date = user.muteUntil?.toUTCDate() {
                        let rep = DateFormatter.log.string(from: date)
                        subtitle = R.string.localizable.mute_until(rep)
                    } else {
                        subtitle = nil
                    }
                    group = [ProfileMenuItem(title: R.string.localizable.muted(),
                                             subtitle: subtitle,
                                             style: [],
                                             action: #selector(mute))]
                } else {
                    group = [ProfileMenuItem(title: R.string.localizable.mute(),
                                             subtitle: nil,
                                             style: [],
                                             action: #selector(mute))]
                }
                if relationship == .FRIEND {
                    group.append(ProfileMenuItem(title: R.string.localizable.edit_name(),
                                                 subtitle: nil,
                                                 style: [],
                                                 action: #selector(editAlias)))
                }
                return group
            }()
            groups.append(muteAndTransactionGroup)

            if !user.isBot {
                let callGroup: [ProfileMenuItem] = {
                    var group = [ProfileMenuItem(title: R.string.localizable.call_with_mixin(),
                                                 subtitle: nil,
                                                 style: [],
                                                 action: #selector(callWithMixin))]
                    if let number = user.phone, !number.isEmpty {
                        group.append(ProfileMenuItem(title: R.string.localizable.phone_call(),
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
                    group.append(ProfileMenuItem(title: R.string.localizable.developer(),
                                                 subtitle: nil,
                                                 style: [],
                                                 action: #selector(showDeveloper)))
                }
                group.append(ProfileMenuItem(title: R.string.localizable.transactions(),
                                             subtitle: nil,
                                             style: [],
                                             action: #selector(showTransactions)))
                return group
            }()
            if !editAliasAndBotRelatedGroup.isEmpty {
                groups.append(editAliasAndBotRelatedGroup)
            }
            
            if !user.isBot {
                let groupsInCommonGroup = [ProfileMenuItem(title: R.string.localizable.groups_in_common(),
                                                           subtitle: nil,
                                                           style: [],
                                                           action: #selector(groupsInCommon))]
                groups.append(groupsInCommonGroup)
            }
            
            let contactRelationshipGroup: [ProfileMenuItem] = {
                var group: [ProfileMenuItem]
                switch relationship {
                case .ME:
                    group = []
                case .FRIEND:
                    let removeTitle = user.isBot ? R.string.localizable.remove_bot() : R.string.localizable.remove_contact()
                    group = [ProfileMenuItem(title: removeTitle,
                                             subtitle: nil,
                                             style: [.destructive],
                                             action: #selector(removeFriend))]
                case .STRANGER:
                    group = [ProfileMenuItem(title: R.string.localizable.block(),
                                             subtitle: nil,
                                             style: [.destructive],
                                             action: #selector(blockUser))]
                case .BLOCKING:
                    group = [ProfileMenuItem(title: R.string.localizable.unblock(),
                                             subtitle: nil,
                                             style: [.destructive],
                                             action: #selector(unblockUser))]
                }
                group.append(ProfileMenuItem(title: R.string.localizable.clear_chat(),
                                             subtitle: nil,
                                             style: [.destructive],
                                             action: #selector(clearChat)))
                return group
            }()
            groups.append(contactRelationshipGroup)
            
            let reportItem = ProfileMenuItem(title: R.string.localizable.report(),
                                             subtitle: nil,
                                             style: [.destructive],
                                             action: #selector(reportUser))
            groups.append([reportItem])
            
            reloadMenu(groups: groups)
            menuStackView.insertArrangedSubview(circleItemView, at: groups.count - 2)
            menuStackView.insertArrangedSubview(expiredMessageItemView, at: 2)
        } else {
            reloadMenu(groups: [])
        }
        
        view.frame.size.width = AppDelegate.current.mainWindow.bounds.width
        updatePreferredContentSizeHeight(size: size)
        
        if updateUserFromRemoteAfterReloaded {
            updateUserFromRemoteAfterReloaded = false
            UserAPI.showUser(userId: user.userId) { [weak self] (result) in
                guard case let .success(response) = result else {
                    return
                }
                self?.handle(userResponse: response)
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
    
    private func handle(userResponse: UserResponse) {
        user = UserItem.createUser(from: userResponse)
        if let animator = sizeAnimator {
            animator.addCompletion { _ in
                self.reloadData()
            }
        } else {
            reloadData()
        }
        UserDAO.shared.updateUsers(users: [userResponse])
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
                    UserDAO.shared.updateUsers(users: [user])
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
                    let view = R.nib.profileFavoriteAppsView(withOwner: nil)!
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
    
    private func reloadMessageExpiration(conversationId: String) {
        expiredMessageItemView.button.isEnabled = false
        DispatchQueue.global().async {
            let expireIn = ConversationDAO.shared.getExpireIn(conversationId: conversationId)
            DispatchQueue.main.sync {
                if let expireIn = expireIn {
                    self.conversationExpireIn = expireIn
                    let subtitle = ExpiredMessageDurationFormatter.string(from: expireIn)
                    self.expiredMessageItemView.subtitleLabel.text = subtitle
                }
                self.expiredMessageItemView.button.isEnabled = true
            }
        }
    }
    
}
