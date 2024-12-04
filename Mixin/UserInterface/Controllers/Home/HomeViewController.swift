import UIKit
import StoreKit
import MixinServices

class HomeViewController: UIViewController {
    
    private enum BulletinDetectInterval {
        static let notificationAuthorization: TimeInterval = 2 * .day
        static let emergencyContact: TimeInterval = 7 * .day
        static let appUpdate: TimeInterval = .day
    }
    
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
    @IBOutlet weak var myAvatarImageView: AvatarImageView!
    
    @IBOutlet weak var bulletinWrapperViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchContainerTopConstraint: NSLayoutConstraint!
    
    private let dragDownThreshold: CGFloat = 80
    private let dragDownIndicator = DragDownIndicator()
    private let feedback = UISelectionFeedbackGenerator()
    private let messageCountPerPage = 30
    private let bulletinContentTopMargin: CGFloat = 10
    private let emergencyContactAlertingUSDBalance = 100
    private let insufficientBalanceForEmergencyContactBulletinReconfirmInterval = secondsPerHour
    
    private var conversations = [ConversationItem]()
    private var needRefresh = true
    private var refreshing = false
    private var beginDraggingOffset: CGFloat = 0
    private var searchViewController: SearchViewController!
    private var searchContainerBeginTopConstant: CGFloat!
    private var loadMoreMessageThreshold = 10
    private var isEditingRow = false
    private var insufficientBalanceForEmergencyContactBulletinConfirmedDate: Date?
    private var isShowingSearch = false
    
    private var bulletinContent: BulletinContent? = nil {
        didSet {
            layoutBulletinView()
        }
    }
    
    private var topLeftTitle: String {
        AppGroupUserDefaults.User.circleName ?? R.string.localizable.mixin()
    }
    
    private weak var bulletinContentViewIfLoaded: BulletinContentView?
    
    private lazy var circlesViewController = R.storyboard.home.circles()!
    private lazy var bulletinContentView: BulletinContentView = {
        let view = R.nib.bulletinContentView(withOwner: self)!
        bulletinWrapperView.addSubview(view)
        view.snp.makeConstraints { (make) in
            make.top.equalToSuperview().offset(bulletinContentTopMargin)
            make.leading.equalToSuperview().offset(14)
            make.trailing.equalToSuperview().offset(-14)
        }
        bulletinContentViewIfLoaded = view
        return view
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
        updateBulletinView()
        searchContainerBeginTopConstant = searchContainerTopConstraint.constant
        searchViewController.cancelButton.addTarget(self, action: #selector(cancelSearching(_:)), for: .touchUpInside)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .singleLine
        tableView.tableFooterView = UIView()
        dragDownIndicator.bounds.size = CGSize(width: 40, height: 40)
        dragDownIndicator.center = CGPoint(x: tableView.frame.width / 2, y: -40)
        tableView.addSubview(dragDownIndicator)
        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange), name: MixinServices.conversationDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange), name: MessageDAO.didInsertMessageNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange), name: MessageDAO.didRedecryptMessageNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(usersDidChange(_:)), name: UserDAO.usersDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadAccount), name: LoginManager.accountDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(circleConversationDidChange(_:)), name: CircleConversationDAO.circleConversationsDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(webSocketDidConnect(_:)), name: WebSocketService.didConnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(webSocketDidDisconnect(_:)), name: WebSocketService.didDisconnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(syncStatusChange), name: ReceiveMessageService.progressNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(groupConversationParticipantDidChange(_:)), name: ReceiveMessageService.groupConversationParticipantDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(circleNameDidChange), name: AppGroupUserDefaults.User.circleNameDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateBulletinView), name: TIP.didUpdateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(cancelSearchingSilently(_:)), name: dismissSearchNotification, object: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            NotificationManager.shared.registerForRemoteNotificationsIfAuthorized()
            CallService.shared.registerForPushKitNotificationsIfAvailable()
        }
        Logger.general.info(category: "HomeViewController", message: "View did load with app state: \(UIApplication.shared.applicationStateString)")
        if UIApplication.shared.applicationState != .background {
            if AppGroupUserDefaults.User.hasRecoverMedia {
                ConcurrentJobQueue.shared.addJob(job: RecoverMediaJob())
            }
            initializeFTSIfNeeded()
            refreshExternalSchemesIfNeeded()
            if SpotlightManager.isAvailable {
                SpotlightManager.shared.indexIfNeeded()
            }
            let job = SyncOutputsJob()
            ConcurrentJobQueue.shared.addJob(job: job)
        }
        UIApplication.homeContainerViewController?.clipSwitcher.loadClipsFromPreviousSession()
        if WalletConnectService.isAvailable {
            WalletConnectService.shared.reloadSessions()
            Web3Chain.synchronize()
        }
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
            let alert = UIAlertController(title: R.string.localizable.setting_emergency_change_mobile(), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: R.string.localizable.later(), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: R.string.localizable.change(), style: .default, handler: { (_) in
                let verify = ChangeNumberPINValidationViewController()
                self.navigationController?.pushViewController(verify, animated: true)
            }))
            present(alert, animated: true, completion: nil)
        }
        if AppGroupUserDefaults.User.isTIPInitialized {
            ConcurrentJobQueue.shared.addJob(job: RecoverRawTransactionJob())
            ConcurrentJobQueue.shared.addJob(job: RefreshAccountJob())
        } else {
            let initialization = InitializeTIPViewController()
            let authentication = AuthenticationViewController(intent: initialization)
            present(authentication, animated: true)
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        dragDownIndicator.center.x = tableView.frame.width / 2
        layoutBulletinView()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        DispatchQueue.main.async(execute: layoutBulletinView)
    }
    
    @IBAction func scanQRCode() {
        UIApplication.homeNavigationController?.pushCameraViewController(asQRCodeScanner: true)
    }
    
    @IBAction func showSearchAction() {
        isShowingSearch = true
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
        navigationController?.pushViewController(UserCenterViewController(), animated: true)
    }
    
    @IBAction func guideAction(_ sender: Any) {
        if let circleId = AppGroupUserDefaults.User.circleId, let name = AppGroupUserDefaults.User.circleName {
            let editor = CircleEditorViewController.instance(name: name, circleId: circleId, isNewCreatedCircle: false)
            present(editor, animated: true, completion: nil)
        } else {
            let vc = ContactViewController.instance(showAddContactButton: false)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @IBAction func bulletinContinueAction(_ sender: Any) {
        switch bulletinContent {
        case .backupMnemonics:
            let introduction = ExportMnemonicPhrasesIntroductionViewController()
            navigationController?.pushViewController(introduction, animated: true)
        case .notification:
            UIApplication.shared.openNotificationSettings()
        case .emergencyContact:
            let vc = AddRecoveryContactViewController()
            navigationController?.pushViewController(vc, animated: true)
        case .appUpdate:
            UIApplication.shared.openAppStorePage()
        case .none:
            break
        }
    }
    
    @IBAction func bulletinDismissAction(_ sender: Any) {
        switch bulletinContent {
        case .backupMnemonics:
            break
        case .notification:
            AppGroupUserDefaults.notificationBulletinDismissalDate = Date()
        case .emergencyContact:
            AppGroupUserDefaults.User.emergencyContactBulletinDismissalDate = Date()
        case .appUpdate:
            AppGroupUserDefaults.appUpdateBulletinDismissalDate = Date()
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
    
    @objc private func applicationDidBecomeActive(_ sender: Notification) {
        updateBulletinView()
        fetchConversations()
        initializeFTSIfNeeded()
        refreshExternalSchemesIfNeeded()
    }
    
    @objc private func dataDidChange() {
        guard view?.isVisibleInScreen ?? false else {
            needRefresh = true
            return
        }
        fetchConversations()
    }
    
    @objc private func usersDidChange(_ sender: Notification) {
        guard let users = sender.userInfo?[UserDAO.UserInfoKey.users] as? [UserResponse], users.count == 1 else {
            return
        }
        dataDidChange()
    }
    
    @objc private func reloadAccount() {
        guard let account = LoginManager.shared.account else {
            return
        }
        if LoginManager.shared.isLoggedIn {
            StickerStore.refreshStickersIfNeeded()
            ExpiredMessageManager.shared.removeExpiredMessages()
        }
        DispatchQueue.main.async {
            self.myAvatarImageView.setImage(with: account)
            self.updateBulletinView()
        }
    }
    
    @objc private func circleConversationDidChange(_ notification: Notification) {
        guard let circleId = notification.userInfo?[CircleConversationDAO.circleIdUserInfoKey] as? String else {
            return
        }
        guard circleId == AppGroupUserDefaults.User.circleId else {
            return
        }
        setNeedsRefresh()
    }
    
    @objc private func webSocketDidConnect(_ notification: Notification) {
        connectingView.stopAnimating()
        titleButton.setTitle(topLeftTitle, for: .normal)
    }
    
    @objc private func webSocketDidDisconnect(_ notification: Notification) {
        connectingView.startAnimating()
        titleButton.setTitle(R.string.localizable.in_connecting(), for: .normal)
    }
    
    @objc private func syncStatusChange(_ notification: Notification) {
        guard let progress = notification.userInfo?[ReceiveMessageService.UserInfoKey.progress] as? Int else {
            return
        }
        if progress >= 100 {
            if WebSocketService.shared.isRealConnected {
                titleButton.setTitle(topLeftTitle, for: .normal)
                connectingView.stopAnimating()
            } else {
                titleButton.setTitle(R.string.localizable.in_connecting(), for: .normal)
                connectingView.startAnimating()
                WebSocketService.shared.connectIfNeeded()
            }
        } else if WebSocketService.shared.isRealConnected {
            let title = R.string.localizable.syncing_progress(progress)
            titleButton.setTitle(title, for: .normal)
            connectingView.startAnimating()
        }
    }
    
    @objc private func groupConversationParticipantDidChange(_ notification: Notification) {
        guard let conversationId = notification.userInfo?[ReceiveMessageService.UserInfoKey.conversationId] as? String else {
            return
        }
        let job = RefreshGroupIconJob(conversationId: conversationId)
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
    @objc func cancelSearching(_ sender: Any) {
        hideSearch(endEditing: true, animate: true)
    }
    
    @objc private func cancelSearchingSilently(_ notification: Notification) {
        if isShowingSearch {
            hideSearch(endEditing: false, animate: false)
        }
    }
    
    @objc private func circleNameDidChange() {
        titleButton.setTitle(topLeftTitle, for: .normal)
    }
    
    func setNeedsRefresh() {
        needRefresh = true
        fetchConversations()
    }
    
    private func hideSearch(endEditing: Bool, animate: Bool) {
        isShowingSearch = false
        searchViewController.willHide()
        searchContainerTopConstraint.constant = searchContainerBeginTopConstant
        let layout = {
            self.navigationBarView.alpha = 1
            self.searchContainerView.alpha = 0
            self.view.layoutIfNeeded()
        }
        if animate {
            UIView.animate(withDuration: 0.2, animations: layout)
        } else {
            layout()
        }
        if endEditing {
            view.endEditing(true)
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
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let conversation = conversations[indexPath.row]
        let actions: [UIContextualAction]
        if conversation.pinTime == nil {
            actions = [deleteAction(forRowAt: indexPath), pinAction(forRowAt: indexPath)]
        } else {
            actions = [deleteAction(forRowAt: indexPath), unpinAction(forRowAt: indexPath)]
        }
        return UISwipeActionsConfiguration(actions: actions)
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
            hideSearch(endEditing: true, animate: true)
        }
    }
    
}

extension HomeViewController {
    
    private func refreshExternalSchemesIfNeeded() {
        if -AppGroupUserDefaults.User.externalSchemesRefreshDate.timeIntervalSinceNow > .day {
            ConcurrentJobQueue.shared.addJob(job: RefreshExternalSchemeJob())
        }
    }
    
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
            guideLabel.text = R.string.localizable.chat_list_empty_info()
            guideButton.setTitle(R.string.localizable.start_messaging(), for: .normal)
        } else {
            guideLabel.text = R.string.localizable.circle_no_conversation_hint()
            guideButton.setTitle(R.string.localizable.add_conversations(), for: .normal)
        }
        guideView.isHidden = false
    }
    
    private func tableViewCommitPinAction(action: UIContextualAction, indexPath: IndexPath, completionHandler: (Bool) -> Void) {
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
        completionHandler(true)
        tableView.setEditing(false, animated: true)
    }
    
    private func tableViewCommitDeleteAction(action: UIContextualAction, indexPath: IndexPath) {
        let conversation = conversations[indexPath.row]
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        alc.addAction(UIAlertAction(title: R.string.localizable.clear_chat(), style: .destructive, handler: { [weak self](action) in
            self?.clearChatAction(indexPath: indexPath)
        }))

        if conversation.category == ConversationCategory.GROUP.rawValue && conversation.status != ConversationStatus.QUIT.rawValue {
            alc.addAction(UIAlertAction(title: R.string.localizable.exit_group(), style: .destructive, handler: { [weak self](action) in
                self?.exitGroupAction(indexPath: indexPath)
            }))
        } else {
            alc.addAction(UIAlertAction(title: R.string.localizable.delete_chat(), style: .destructive, handler: { [weak self](action) in
                self?.deleteChatAction(indexPath: indexPath)
            }))
        }

        alc.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        self.present(alc, animated: true, completion: nil)
        tableView.setEditing(false, animated: true)
    }

    private func deleteChatAction(indexPath: IndexPath) {
        let conversation = conversations[indexPath.row]
        let conversationId = conversation.conversationId
        let alert: UIAlertController
        if conversation.category == ConversationCategory.GROUP.rawValue {
            alert = UIAlertController(title: R.string.localizable.delete_group_chat_confirmation(conversation.name), message: nil, preferredStyle: .actionSheet)
        } else {
            alert = UIAlertController(title: R.string.localizable.delete_contact_chat_confirmation(conversation.ownerFullName), message: nil, preferredStyle: .actionSheet)
        }
        alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.delete_chat(), style: .destructive, handler: { (_) in
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
            alert = UIAlertController(title: R.string.localizable.clear_group_chat_confirmation(conversation.name), message: nil, preferredStyle: .actionSheet)
        } else {
            alert = UIAlertController(title: R.string.localizable.clear_contact_chat_confirmation(conversation.ownerFullName), message: nil, preferredStyle: .actionSheet)
        }
        alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.clear_chat(), style: .destructive, handler: { (_) in
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
        let alert = UIAlertController(title: R.string.localizable.exit_confirmation(conversation.name), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.exit_group(), style: .destructive, handler: { (_) in
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                let scene = UIApplication.shared.connectedScenes.lazy
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive })
                if let scene {
                    SKStoreReviewController.requestReview(in: scene)
                }
            }
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
    
    @objc private func updateBulletinView() {
        Task {
            func isDate(_ date: Date?, fallsInto interval: TimeInterval) -> Bool {
                if let date = date {
                    return -date.timeIntervalSinceNow < interval
                } else {
                    return false
                }
            }
            
            guard let account = LoginManager.shared.account else {
                return
            }
            
            var content: BulletinContent?
            
            if account.isAnonymous, !account.hasSaltExported {
                content = .backupMnemonics
            }
            
            if content == nil {
                let userJustDismissedNotificationBulletin = isDate(AppGroupUserDefaults.notificationBulletinDismissalDate, fallsInto: BulletinDetectInterval.notificationAuthorization)
                if !userJustDismissedNotificationBulletin, await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied {
                    content = .notification
                }
            }
            
            if content == nil, !account.isAnonymous {
                let checkWalletBalance = await MainActor.run {
                    if account.hasEmergencyContact {
                        // User has emergency contact set
                        return false
                    } else if isDate(AppGroupUserDefaults.User.emergencyContactBulletinDismissalDate, fallsInto: BulletinDetectInterval.emergencyContact) {
                        // User just dismissed the bulletin of emergency contact
                        return false
                    } else if isDate(insufficientBalanceForEmergencyContactBulletinConfirmedDate, fallsInto: insufficientBalanceForEmergencyContactBulletinReconfirmInterval) {
                        // Just confirmed user doesn't have enough money
                        return false
                    } else {
                        return true
                    }
                }
                if checkWalletBalance {
                    let isRichEnough: Bool = await withCheckedContinuation { continuation in
                        DispatchQueue.global().async {
                            let balance = TokenDAO.shared.usdBalanceSum()
                            DispatchQueue.main.async {
                                if balance > self.emergencyContactAlertingUSDBalance {
                                    continuation.resume(returning: true)
                                } else {
                                    self.insufficientBalanceForEmergencyContactBulletinConfirmedDate = Date()
                                    continuation.resume(returning: false)
                                }
                            }
                        }
                    }
                    if isRichEnough {
                        content = .emergencyContact
                    }
                }
            }
            
            if content == nil {
                let userJustDismissedUpdateBulletin = isDate(AppGroupUserDefaults.appUpdateBulletinDismissalDate, fallsInto: BulletinDetectInterval.appUpdate)
                if !userJustDismissedUpdateBulletin,
                   let latestVersion = account.system?.messenger.version,
                   let currentVersion = Bundle.main.shortVersion,
                   currentVersion < latestVersion
                {
                    content = .appUpdate
                }
            }
            
            await MainActor.run {
                bulletinContentView.content = content
                bulletinContent = content
                if view.window != nil {
                    view.layoutIfNeeded()
                }
            }
        }
    }
    
    private func deleteAction(forRowAt indexPath: IndexPath) -> UIContextualAction {
        UIContextualAction(style: .destructive, title: R.string.localizable.delete()) { [weak self] (action, _, completionHandler: (Bool) -> Void) in
            self?.tableViewCommitDeleteAction(action: action, indexPath: indexPath)
            completionHandler(true)
        }
    }
    
    private func pinAction(forRowAt indexPath: IndexPath) -> UIContextualAction {
        let action = UIContextualAction(style: .destructive, title: R.string.localizable.pin_title()) { [weak self] (action, _, completionHandler: (Bool) -> Void) in
            self?.tableViewCommitPinAction(action: action, indexPath: indexPath, completionHandler: completionHandler)
        }
        action.backgroundColor = .theme
        return action
    }
    
    private func unpinAction(forRowAt indexPath: IndexPath) -> UIContextualAction {
        let action = UIContextualAction(style: .normal, title: R.string.localizable.unpin()) { [weak self] (action, _, completionHandler: (Bool) -> Void) in
            self?.tableViewCommitPinAction(action: action, indexPath: indexPath, completionHandler: completionHandler)
        }
        action.backgroundColor = .theme
        return action
    }
    
}
