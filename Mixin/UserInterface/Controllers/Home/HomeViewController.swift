import UIKit
import AVFoundation
import StoreKit
import MixinServices

class HomeViewController: UIViewController {
    
    static var hasTriedToRequestReview = false
    static var showChangePhoneNumberTips = false
    
    @IBOutlet weak var navigationBarView: UIView!
    @IBOutlet weak var searchContainerView: UIView!
    @IBOutlet weak var circlesContainerView: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var guideView: UIView!
    @IBOutlet weak var guideLabel: UILabel!
    @IBOutlet weak var guideButton: UIButton!
    @IBOutlet weak var connectingView: ActivityIndicatorView!
    @IBOutlet weak var titleButton: HomeTitleButton!
    @IBOutlet weak var bulletinWrapperView: UIView!
    @IBOutlet weak var bottomBarView: UIView!
    @IBOutlet weak var appStackView: UIStackView!
    @IBOutlet weak var myAvatarImageView: AvatarImageView!
    @IBOutlet weak var desktopButton: UIButton!
    
    @IBOutlet weak var bulletinWrapperViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchContainerTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomNavigationBottomConstraint: NSLayoutConstraint!
    
    private let dragDownThreshold: CGFloat = 80
    private let dragDownIndicator = DragDownIndicator()
    private let feedback = UISelectionFeedbackGenerator()
    private let messageCountPerPage = 30
    private let numberOfHomeApps = 3
    private let bulletinContentTopMargin: CGFloat = 10
    private let notificationAuthorizationAlertingInterval = 2 * secondsPerDay
    private let emergencyContactAlertingInterval = 7 * secondsPerDay
    private let emergencyContactAlertingUSDBalance = 100
    private let insufficientBalanceForEmergencyContactBulletinReconfirmInterval = secondsPerHour
    
    private var conversations = [ConversationItem]()
    private var needRefresh = true
    private var refreshing = false
    private var beginDraggingOffset: CGFloat = 0
    private var searchViewController: SearchViewController!
    private var searchContainerBeginTopConstant: CGFloat!
    private var loadMoreMessageThreshold = 10
    private var appButtons = [UIButton]()
    private var appActions: [(() -> Void)?] = []
    private var isEditingRow = false
    private var insufficientBalanceForEmergencyContactBulletinConfirmedDate: Date?
    
    private var bulletinContent: BulletinContent? = nil {
        didSet {
            layoutBulletinView()
        }
    }
    
    private var topLeftTitle: String {
        AppGroupUserDefaults.User.circleName ?? R.string.localizable.app_name()
    }
    
    private weak var bulletinContentViewIfLoaded: BulletinContentView?
    
    private lazy var circlesViewController = R.storyboard.home.circles()!
    private lazy var bulletinContentView: BulletinContentView = {
        let view = R.nib.bulletinContentView(owner: self)!
        bulletinWrapperView.addSubview(view)
        view.snp.makeConstraints { (make) in
            make.top.equalToSuperview().offset(bulletinContentTopMargin)
            make.leading.equalToSuperview().offset(14)
            make.trailing.equalToSuperview().offset(-14)
        }
        bulletinContentViewIfLoaded = view
        return view
    }()
    private lazy var deleteAction = UITableViewRowAction(style: .destructive, title: Localized.MENU_DELETE, handler: tableViewCommitDeleteAction)
    private lazy var pinAction: UITableViewRowAction = {
        let action = UITableViewRowAction(style: .normal, title: Localized.HOME_CELL_ACTION_PIN, handler: tableViewCommitPinAction)
        action.backgroundColor = .theme
        return action
    }()
    private lazy var unpinAction: UITableViewRowAction = {
        let action = UITableViewRowAction(style: .normal, title: Localized.HOME_CELL_ACTION_UNPIN, handler: tableViewCommitPinAction)
        action.backgroundColor = .theme
        return action
    }()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let vc = (segue.destination as? UINavigationController)?.viewControllers.first as? SearchViewController {
            searchViewController = vc
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleButton.setTitle(topLeftTitle, for: .normal)
        if let account = LoginManager.shared.account {
            myAvatarImageView.setImage(with: account)
        }
        updateDesktopButtonHidden()
        updateBulletinView()
        searchContainerBeginTopConstant = searchContainerTopConstraint.constant
        searchViewController.cancelButton.addTarget(self, action: #selector(hideSearch), for: .touchUpInside)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .singleLine
        tableView.tableFooterView = UIView()
        dragDownIndicator.bounds.size = CGSize(width: 40, height: 40)
        dragDownIndicator.center = CGPoint(x: tableView.frame.width / 2, y: -40)
        tableView.addSubview(dragDownIndicator)
        for index in 0..<numberOfHomeApps {
            let button = UIButton()
            button.tintColor = R.color.icon_tint()
            button.tag = index
            button.addTarget(self, action: #selector(homeAppAction(_:)), for: .touchUpInside)
            appButtons.append(button)
            appStackView.insertArrangedSubview(button, at: appStackView.arrangedSubviews.count - 1)
            button.snp.makeConstraints { (make) in
                make.width.equalTo(button.snp.height)
            }
            appActions.append(nil)
        }
        updateHomeApps()
        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange(_:)), name: MixinServices.conversationDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange(_:)), name: MessageDAO.didInsertMessageNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange(_:)), name: MessageDAO.didRedecryptMessageNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange(_:)), name: UserDAO.userDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadAccount), name: LoginManager.accountDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidChange(_:)), name: UserDAO.correspondingAppDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(circleConversationDidChange(_:)), name: CircleConversationDAO.circleConversationsDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(webSocketDidConnect(_:)), name: WebSocketService.didConnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(webSocketDidDisconnect(_:)), name: WebSocketService.didDisconnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(syncStatusChange), name: ReceiveMessageService.progressNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(groupConversationParticipantDidChange(_:)), name: ReceiveMessageService.groupConversationParticipantDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(circleNameDidChange), name: AppGroupUserDefaults.User.circleNameDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateHomeApps), name: AppGroupUserDefaults.User.homeAppIdsDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateDesktopButtonHidden), name: AppGroupUserDefaults.Account.extensionSessionDidChangeNotification, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            NotificationManager.shared.registerForRemoteNotificationsIfAuthorized()
            CallService.shared.registerForPushKitNotificationsIfAvailable()
        }
        Logger.general.info(category: "HomeViewController", message: "View did load with app state: \(UIApplication.shared.applicationStateString)")
        if UIApplication.shared.applicationState != .background {
            ConcurrentJobQueue.shared.addJob(job: RefreshAccountJob())
            ConcurrentJobQueue.shared.addJob(job: CleanUpUnusedAttachmentJob())
            if AppGroupUserDefaults.User.hasRecoverMedia {
                ConcurrentJobQueue.shared.addJob(job: RecoverMediaJob())
            }
            initializeFTSIfNeeded()
        }
        UIApplication.homeContainerViewController?.clipSwitcher.loadClipsFromPreviousSession()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if needRefresh {
            fetchConversations()
        }
        checkServerStatus()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        #if RELEASE
        requestAppStoreReviewIfNeeded()
        #endif
        if HomeViewController.showChangePhoneNumberTips {
            HomeViewController.showChangePhoneNumberTips = false
            let alert = UIAlertController(title: R.string.localizable.emergency_change_number_tip(), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: R.string.localizable.action_later(), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_change(), style: .default, handler: { (_) in
                let vc = VerifyPinNavigationController(rootViewController: ChangeNumberVerifyPinViewController())
                self.present(vc, animated: true, completion: nil)
            }))
            present(alert, animated: true, completion: nil)
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        dragDownIndicator.center.x = tableView.frame.width / 2
        layoutBulletinView()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        let bottom = bottomBarView.frame.height - view.safeAreaInsets.bottom
        tableView.contentInset.bottom = bottom
        if view.safeAreaInsets.bottom < 1 {
            bottomNavigationBottomConstraint.constant = 24
            bottomBarView.layoutIfNeeded()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        DispatchQueue.main.async(execute: layoutBulletinView)
    }
    

    @IBAction func showDesktopAction() {
        navigationController?.pushViewController(DesktopViewController.instance(), animated: true)
    }
    
    @IBAction func showSearchAction() {
        searchViewController.prepareForReuse()
        searchContainerTopConstraint.constant = 0
        UIView.animate(withDuration: 0.2, animations: {
            self.navigationBarView.alpha = 0
            self.searchContainerView.alpha = 1
            self.view.layoutIfNeeded()
        }) { (_) in
            self.searchViewController.searchTextField.becomeFirstResponder()
        }
    }
    
    @IBAction func contactsAction(_ sender: Any) {
        navigationController?.pushViewController(ContactViewController.instance(), animated: true)
    }
    
    @IBAction func guideAction(_ sender: Any) {
        if let circleId = AppGroupUserDefaults.User.circleId, let name = AppGroupUserDefaults.User.circleName {
            let editor = CircleEditorViewController.instance(name: name, circleId: circleId, isNewCreatedCircle: false)
            present(editor, animated: true, completion: nil)
        } else {
            let vc = ContactViewController.instance()
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @IBAction func bulletinContinueAction(_ sender: Any) {
        switch bulletinContent {
        case .notification:
            UIApplication.openAppSettings()
        case .emergencyContact:
            let vc = EmergencyContactViewController.instance()
            navigationController?.pushViewController(vc, animated: true)
        case .none:
            break
        }
    }
    
    @IBAction func bulletinDismissAction(_ sender: Any) {
        switch bulletinContent {
        case .notification:
            AppGroupUserDefaults.notificationBulletinDismissalDate = Date()
        case .emergencyContact:
            AppGroupUserDefaults.User.emergencyContactBulletinDismissalDate = Date()
        case .none:
            break
        }
        UIView.animate(withDuration: 0.3) {
            self.bulletinContent = nil
            self.view.layoutIfNeeded()
        }
    }
    
    @IBAction func toggleCircles(_ sender: Any) {
        if circlesContainerView.isHidden {
            if circlesViewController.parent == nil {
                circlesViewController.view.frame = circlesContainerView.bounds
                circlesViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                addChild(circlesViewController)
                circlesContainerView.addSubview(circlesViewController.view)
                circlesViewController.didMove(toParent: self)
            }
            circlesViewController.setTableViewVisible(false, animated: false, completion: nil)
            circlesContainerView.isHidden = false
            circlesViewController.setTableViewVisible(true, animated: true, completion: nil)
        } else {
            circlesViewController.setTableViewVisible(false, animated: true, completion: {
                self.circlesContainerView.isHidden = true
            })
        }
    }
    
    @IBAction func showAppsAction(_ sender: Any) {
        let vc = HomeAppsViewController.instance()
        vc.presentAsChild(of: self)
    }
    
    @objc func applicationDidBecomeActive(_ sender: Notification) {
        updateBulletinView()
        fetchConversations()
        initializeFTSIfNeeded()
    }
    
    @objc func dataDidChange(_ sender: Notification) {
        guard view?.isVisibleInScreen ?? false else {
            needRefresh = true
            return
        }
        fetchConversations()
    }
    
    @objc func reloadAccount() {
        guard let account = LoginManager.shared.account else {
            return
        }
        if LoginManager.shared.isLoggedIn {
            StickerStore.refreshStickersIfNeeded()
        }
        DispatchQueue.main.async {
            self.myAvatarImageView.setImage(with: account)
            if self.bulletinContent == .emergencyContact && account.has_emergency_contact {
                self.bulletinContent = nil
            }
        }
    }

    @objc func appDidChange(_ notification: Notification) {
        guard let app = notification.userInfo?[UserDAO.UserInfoKey.app] as? App else {
            return
        }
        guard AppGroupUserDefaults.User.homeAppIds.contains(app.appId) else {
            return
        }
        updateHomeApps()
    }
    
    @objc func circleConversationDidChange(_ notification: Notification) {
        guard let circleId = notification.userInfo?[CircleConversationDAO.circleIdUserInfoKey] as? String else {
            return
        }
        guard circleId == AppGroupUserDefaults.User.circleId else {
            return
        }
        setNeedsRefresh()
    }
    
    @objc func webSocketDidConnect(_ notification: Notification) {
        connectingView.stopAnimating()
        titleButton.setTitle(topLeftTitle, for: .normal)
    }
    
    @objc func webSocketDidDisconnect(_ notification: Notification) {
        connectingView.startAnimating()
        titleButton.setTitle(R.string.localizable.dialog_progress_connect(), for: .normal)
    }
    
    @objc func syncStatusChange(_ notification: Notification) {
        guard let progress = notification.userInfo?[ReceiveMessageService.UserInfoKey.progress] as? Int else {
            return
        }
        if progress >= 100 {
            if WebSocketService.shared.isRealConnected {
                titleButton.setTitle(topLeftTitle, for: .normal)
                connectingView.stopAnimating()
            } else {
                titleButton.setTitle(R.string.localizable.dialog_progress_connect(), for: .normal)
                connectingView.startAnimating()
                WebSocketService.shared.connectIfNeeded()
            }
        } else if WebSocketService.shared.isRealConnected {
            let title = Localized.CONNECTION_HINT_PROGRESS(progress)
            titleButton.setTitle(title, for: .normal)
            connectingView.startAnimating()
        }
    }
    
    @objc func groupConversationParticipantDidChange(_ notification: Notification) {
        guard let conversationId = notification.userInfo?[ReceiveMessageService.UserInfoKey.conversationId] as? String else {
            return
        }
        let job = RefreshGroupIconJob(conversationId: conversationId)
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
    @objc func hideSearch() {
        searchViewController.willHide()
        searchContainerTopConstraint.constant = searchContainerBeginTopConstant
        UIView.animate(withDuration: 0.2) {
            self.navigationBarView.alpha = 1
            self.searchContainerView.alpha = 0
            self.view.layoutIfNeeded()
        }
        view.endEditing(true)
    }
    
    @objc func circleNameDidChange() {
        titleButton.setTitle(topLeftTitle, for: .normal)
    }
    
    @objc func homeAppAction(_ button: UIButton) {
        appActions[button.tag]?()
    }
    
    @objc func updateHomeApps() {
        func action(for app: HomeApp) -> (() -> Void) {
            switch app {
            case .embedded(let app):
                return app.action
            case .external(let user):
                return {
                    ConcurrentJobQueue.shared.addJob(job: RefreshUserJob(userIds: [user.userId]))
                    if let app = user.app {
                        let userInfo = ["source": "Home", "identityNumber": app.appNumber]
                        reporter.report(event: .openApp, userInfo: userInfo)
                        MixinWebViewController.presentInstance(with: .init(conversationId: "", app: app), asChildOf: self)
                    } else {
                        reporter.report(error: MixinError.missingApp)
                    }
                }
            }
        }
        
        DispatchQueue.global().async {
            let apps = AppGroupUserDefaults.User.homeAppIds
                .compactMap(HomeApp.init)
                .prefix(self.numberOfHomeApps)
            DispatchQueue.main.async {
                for index in 0..<self.numberOfHomeApps {
                    if index < apps.count {
                        let button = self.appButtons[index]
                        let app = apps[index]
                        button.setImage(app.categoryIcon, for: .normal)
                        button.isHidden = false
                        self.appActions[index] = action(for: app)
                    } else {
                        self.appButtons[index].isHidden = true
                        self.appActions[index] = nil
                    }
                }
                if apps.count <= 2 {
                    self.appStackView.spacing = 8
                } else {
                    self.appStackView.spacing = 0
                }
                UIView.animate(withDuration: 0.15) {
                    self.appStackView.alpha = 1
                }
            }
        }
    }
    
    @objc private func updateDesktopButtonHidden() {
        desktopButton.isHidden = !AppGroupUserDefaults.Account.isDesktopLoggedIn
    }
    
    func dismissAppsWindow() {
        if let homeApps = children.compactMap({ $0 as? HomeAppsViewController }).first {
            homeApps.dismissAsChild(completion: nil)
        }
    }
    
    func setNeedsRefresh() {
        needRefresh = true
        fetchConversations()
    }
    
    func showCamera(asQrCodeScanner: Bool) {
        let vc = CameraViewController.instance()
        vc.asQrCodeScanner = asQrCodeScanner
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            navigationController?.pushViewController(vc, animated: true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { [weak self](granted) in
                guard granted else {
                    return
                }
                DispatchQueue.main.async {
                    self?.navigationController?.pushViewController(vc, animated: true)
                }
            })
        case .denied, .restricted:
            alertSettings(Localized.PERMISSION_DENIED_CAMERA)
        @unknown default:
            alertSettings(Localized.PERMISSION_DENIED_CAMERA)
        }
    }
    
}

extension HomeViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.conversation, for: indexPath)!
        cell.render(item: conversations[indexPath.row])
        return cell
    }
    
}

extension HomeViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let conversation = conversations[indexPath.row]
        if conversation.status == ConversationStatus.START.rawValue {
            let job = CreateConversationJob(conversationId: conversation.conversationId)
            ConcurrentJobQueue.shared.addJob(job: job)
        } else {
            conversation.unseenMessageCount = 0
            let vc = ConversationViewController.instance(conversation: conversation)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) {
        isEditingRow = true
    }

    func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
        isEditingRow = false
        fetchConversations()
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let conversation = conversations[indexPath.row]
        if conversation.pinTime == nil {
            return [deleteAction, pinAction]
        } else {
            return [deleteAction, unpinAction]
        }
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard conversations.count >= messageCountPerPage else {
            return
        }
        guard indexPath.row > conversations.count - loadMoreMessageThreshold else {
            return
        }
        guard !refreshing else {
            needRefresh = true
            return
        }

        fetchConversations()
    }
    
}

extension HomeViewController: UIScrollViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        beginDraggingOffset = scrollView.contentOffset.y
        feedback.prepare()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y <= -dragDownThreshold && !dragDownIndicator.isHighlighted {
            dragDownIndicator.isHighlighted = true
            feedback.selectionChanged()
        } else if scrollView.contentOffset.y > -dragDownThreshold && dragDownIndicator.isHighlighted {
            dragDownIndicator.isHighlighted = false
        }
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if tableView.contentOffset.y <= -dragDownThreshold {
            showSearchAction()
        } else {
            hideSearch()
        }
    }
    
}

extension HomeViewController {
    
    private func initializeFTSIfNeeded() {
        guard !AppGroupUserDefaults.Database.isFTSInitialized else {
            return
        }
        ConcurrentJobQueue.shared.addJob(job: InitializeFTSJob())
    }
    
    private func checkServerStatus() {
        guard LoginManager.shared.isLoggedIn else {
            return
        }
        guard !WebSocketService.shared.isConnected else {
            return
        }
        AccountAPI.me { (result) in
            guard case .failure(.requiresUpdate) = result else {
                return
            }
            WebSocketService.shared.disconnect()
            AppDelegate.current.mainWindow.rootViewController = UpdateViewController.instance()
        }
    }
    
    private func fetchConversations() {
        guard LoginManager.shared.isLoggedIn else {
            return
        }
        guard !refreshing else {
            needRefresh = true
            return
        }
        refreshing = true
        needRefresh = false

        DispatchQueue.main.async {
            if AppGroupUserDefaults.User.circleId == nil {
                self.titleButton.showsTopRightDot = false
            }
            let limit = (self.tableView.indexPathsForVisibleRows?.first?.row ?? 0) + self.messageCountPerPage

            DispatchQueue.global().async { [weak self] in
                let circleId = AppGroupUserDefaults.User.circleId
                let conversations = ConversationDAO.shared.conversationList(limit: limit, circleId: circleId)
                let groupIcons = conversations.filter({ $0.isNeedCachedGroupIcon() })
                for conversation in groupIcons {
                    ConcurrentJobQueue.shared.addJob(job: RefreshGroupIconJob(conversationId: conversation.conversationId))
                }
                let hasUnreadMessagesOutsideCircle: Bool = {
                    if let id = circleId {
                        return ConversationDAO.shared.hasUnreadMessage(outsideCircleWith: id)
                    } else {
                        return false
                    }
                }()
                DispatchQueue.main.async {
                    guard self?.tableView != nil, !(self?.isEditingRow ?? false) else {
                         self?.refreshing = false
                        return
                    }
                    self?.conversations = conversations
                    self?.tableView.reloadData()
                    self?.titleButton.showsTopRightDot = hasUnreadMessagesOutsideCircle
                    self?.updateGuideView()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.33, execute: {
                        self?.refreshing = false
                        if self?.needRefresh ?? false {
                            self?.fetchConversations()
                        }
                    })
                }
            }
        }
    }
    
    private func updateGuideView() {
        guard conversations.isEmpty else {
            guideView.isHidden = true
            return
        }
        if AppGroupUserDefaults.User.circleId == nil {
            guideLabel.text = R.string.localizable.home_start_messaging_guide()
            guideButton.setTitle(R.string.localizable.home_start_messaging(), for: .normal)
        } else {
            guideLabel.text = R.string.localizable.circle_no_conversation_hint()
            guideButton.setTitle(R.string.localizable.circle_no_conversation_action(), for: .normal)
        }
        guideView.isHidden = false
    }
    
    private func tableViewCommitPinAction(action: UITableViewRowAction, indexPath: IndexPath) {
        let dao = ConversationDAO.shared
        let conversation = conversations[indexPath.row]
        let destinationIndex: Int
        if conversation.pinTime == nil {
            let pinTime = Date().toUTCString()
            conversation.pinTime = pinTime
            dao.updateConversation(with: conversation.conversationId,
                                   inCirleOf: AppGroupUserDefaults.User.circleId,
                                   pinTime: pinTime)
            conversations.remove(at: indexPath.row)
            destinationIndex = 0
        } else {
            conversation.pinTime = nil
            dao.updateConversation(with: conversation.conversationId,
                                   inCirleOf: AppGroupUserDefaults.User.circleId,
                                   pinTime: nil)
            conversations.remove(at: indexPath.row)
            destinationIndex = conversations.firstIndex(where: { $0.pinTime == nil && $0.createdAt < conversation.createdAt }) ?? conversations.count
        }
        conversations.insert(conversation, at: destinationIndex)
        let destinationIndexPath = IndexPath(row: destinationIndex, section: 0)
        tableView.moveRow(at: indexPath, to: destinationIndexPath)
        if let cell = tableView.cellForRow(at: destinationIndexPath) as? ConversationCell {
            cell.render(item: conversation)
        }
        tableView.setEditing(false, animated: true)
    }
    
    private func tableViewCommitDeleteAction(action: UITableViewRowAction, indexPath: IndexPath) {
        let conversation = conversations[indexPath.row]
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        alc.addAction(UIAlertAction(title: R.string.localizable.group_menu_clear(), style: .destructive, handler: { [weak self](action) in
            self?.clearChatAction(indexPath: indexPath)
        }))

        if conversation.category == ConversationCategory.GROUP.rawValue && conversation.status != ConversationStatus.QUIT.rawValue {
            alc.addAction(UIAlertAction(title: R.string.localizable.group_menu_exit(), style: .destructive, handler: { [weak self](action) in
                self?.exitGroupAction(indexPath: indexPath)
            }))
        } else {
            alc.addAction(UIAlertAction(title: R.string.localizable.group_menu_delete(), style: .destructive, handler: { [weak self](action) in
                self?.deleteChatAction(indexPath: indexPath)
            }))
        }

        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        self.present(alc, animated: true, completion: nil)
        tableView.setEditing(false, animated: true)
    }

    private func deleteChatAction(indexPath: IndexPath) {
        let conversation = conversations[indexPath.row]
        let conversationId = conversation.conversationId
        let alert: UIAlertController
        if conversation.category == ConversationCategory.GROUP.rawValue {
            alert = UIAlertController(title: R.string.localizable.profile_delete_group_chat_hint(conversation.name), message: nil, preferredStyle: .actionSheet)
        } else {
            alert = UIAlertController(title: R.string.localizable.profile_delete_contact_chat_hint(conversation.ownerFullName), message: nil, preferredStyle: .actionSheet)
        }
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.group_menu_delete(), style: .destructive, handler: { (_) in
            self.tableView.beginUpdates()
            self.conversations.remove(at: indexPath.row)
            self.tableView.deleteRows(at: [indexPath], with: .fade)
            self.tableView.endUpdates()
            DispatchQueue.global().async {
                ConversationDAO.shared.deleteChat(conversationId: conversationId)
            }
        }))
        present(alert, animated: true, completion: nil)
    }
    
    private func clearChatAction(indexPath: IndexPath) {
        let conversation = conversations[indexPath.row]
        let conversationId = conversation.conversationId
        let alert: UIAlertController
        if conversation.category == ConversationCategory.GROUP.rawValue {
            alert = UIAlertController(title: R.string.localizable.profile_clear_group_chat_hint(conversation.name), message: nil, preferredStyle: .actionSheet)
        } else {
            alert = UIAlertController(title: R.string.localizable.profile_clear_contact_chat_hint(conversation.ownerFullName), message: nil, preferredStyle: .actionSheet)
        }
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.group_menu_clear(), style: .destructive, handler: { (_) in
            self.tableView.beginUpdates()
            self.conversations[indexPath.row].contentType = MessageCategory.UNKNOWN.rawValue
            self.conversations[indexPath.row].messageId = ""
            self.conversations[indexPath.row].unseenMessageCount = 0
            self.tableView.reloadRows(at: [indexPath], with: .automatic)
            self.tableView.endUpdates()
            DispatchQueue.global().async {
                ConversationDAO.shared.clearChat(conversationId: conversationId)
            }
        }))
        present(alert, animated: true, completion: nil)
    }

    private func exitGroupAction(indexPath: IndexPath) {
        let conversation = conversations[indexPath.row]
        let conversationId = conversation.conversationId
        let alert = UIAlertController(title: R.string.localizable.profile_exit_group_hint(conversation.name), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.group_menu_exit(), style: .destructive, handler: { (_) in
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            ConversationAPI.exitConversation(conversationId: conversationId) { [weak self](result) in
                switch result {
                case .success:
                    hud.hide()
                    self?.conversations[indexPath.row].status = ConversationStatus.QUIT.rawValue
                    DispatchQueue.global().async {
                        ConversationDAO.shared.exitGroup(conversationId: conversationId)
                    }
                case let .failure(error):
                    switch error {
                    case .forbidden, .notFound:
                        hud.hide()
                        self?.conversations[indexPath.row].status = ConversationStatus.QUIT.rawValue
                        DispatchQueue.global().async {
                            ConversationDAO.shared.exitGroup(conversationId: conversationId)
                        }
                    default:
                        hud.set(style: .error, text: error.localizedDescription)
                        hud.scheduleAutoHidden()
                    }
                }
            }
        }))
        present(alert, animated: true, completion: nil)
    }
    
    private func requestAppStoreReviewIfNeeded() {
        guard let firstLaunchDate = AppGroupUserDefaults.firstLaunchDate else {
            return
        }
        let sevenDays: Double = 7 * 24 * 60 * 60
        let shouldRequestReview = !HomeViewController.hasTriedToRequestReview
            && AppGroupUserDefaults.User.hasPerformedTransfer
            && -firstLaunchDate.timeIntervalSinceNow > sevenDays
        if shouldRequestReview {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                SKStoreReviewController.requestReview()
            })
        }
        HomeViewController.hasTriedToRequestReview = true
    }
    
    private func layoutBulletinView() {
        if bulletinContent == nil {
            bulletinWrapperViewHeightConstraint.constant = 0
            bulletinContentViewIfLoaded?.alpha = 0
        } else {
            UIView.performWithoutAnimation(bulletinContentView.layoutIfNeeded)
            bulletinWrapperViewHeightConstraint.constant = bulletinContentTopMargin + bulletinContentView.frame.height
            bulletinContentView.alpha = 1
        }
    }
    
    private func updateBulletinView() {
        func isDateNonNil(_ date: Date?, hasLessIntervalSinceNowThan interval: TimeInterval) -> Bool {
            guard let date = date else {
                return false
            }
            return -date.timeIntervalSinceNow < interval
        }
        
        let userJustDismissedNotificationBulletin = isDateNonNil(AppGroupUserDefaults.notificationBulletinDismissalDate, hasLessIntervalSinceNowThan: notificationAuthorizationAlertingInterval)
        let checkNotificationSettings = !userJustDismissedNotificationBulletin
        
        let checkWalletBalanceForEmergencyContactBulletin: Bool
        let userJustDismissedEmergencyContactBulletin = isDateNonNil(AppGroupUserDefaults.User.emergencyContactBulletinDismissalDate, hasLessIntervalSinceNowThan: emergencyContactAlertingInterval)
        let justConfirmedUserHasInsufficientBalanceForEmergencyContactBulletin = isDateNonNil(insufficientBalanceForEmergencyContactBulletinConfirmedDate, hasLessIntervalSinceNowThan: insufficientBalanceForEmergencyContactBulletinReconfirmInterval)
        if bulletinContent == .notification
            || userJustDismissedEmergencyContactBulletin
            || justConfirmedUserHasInsufficientBalanceForEmergencyContactBulletin
            || (LoginManager.shared.account?.has_emergency_contact ?? false)
        {
            checkWalletBalanceForEmergencyContactBulletin = false
        } else {
            checkWalletBalanceForEmergencyContactBulletin = true
        }
        
        guard checkNotificationSettings || checkWalletBalanceForEmergencyContactBulletin else {
            return
        }
        
        func show(content: BulletinContent?) {
            bulletinContentView.content = content
            bulletinContent = content
            if view.window != nil {
                view.layoutIfNeeded()
            }
        }
        
        func showEmergencyContactBulletinIfNeeded() {
            DispatchQueue.global().async {
                let balance = AssetDAO.shared.getTotalUSDBalance()
                DispatchQueue.main.async {
                    if balance > self.emergencyContactAlertingUSDBalance {
                        show(content: .emergencyContact)
                    } else {
                        self.insufficientBalanceForEmergencyContactBulletinConfirmedDate = Date()
                    }
                }
            }
        }
        
        if checkNotificationSettings {
            UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                DispatchQueue.main.async {
                    if settings.authorizationStatus == .denied {
                        show(content: .notification)
                    } else if checkWalletBalanceForEmergencyContactBulletin {
                        showEmergencyContactBulletinIfNeeded()
                    } else {
                        show(content: nil)
                    }
                }
            }
        } else if checkWalletBalanceForEmergencyContactBulletin {
            showEmergencyContactBulletinIfNeeded()
        }
    }
    
}
