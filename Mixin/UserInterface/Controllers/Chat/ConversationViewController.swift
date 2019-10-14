import UIKit
import MobileCoreServices
import AVKit
import Photos

class ConversationViewController: UIViewController {
    
    static var positions = [String: Position]()
    
    @IBOutlet weak var navigationBarView: UIView!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tableView: ConversationTableView!
    @IBOutlet weak var announcementButton: UIButton!
    @IBOutlet weak var scrollToBottomWrapperView: UIView!
    @IBOutlet weak var scrollToBottomButton: UIButton!
    @IBOutlet weak var unreadBadgeLabel: UILabel!
    @IBOutlet weak var inputWrapperView: UIView!
    @IBOutlet weak var inputWrapperTopShadowView: TopShadowView!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var loadingView: ActivityIndicatorView!
    @IBOutlet weak var titleStackView: UIStackView!
    
    @IBOutlet weak var navigationBarTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollToBottomWrapperHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputWrapperHeightConstraint: NSLayoutConstraint!
    
    var dataSource: ConversationDataSource!
    var conversationId: String {
        return dataSource.conversationId
    }
    var statusBarHidden = false {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    private let minInputWrapperTopMargin: CGFloat = 112 // Margin to navigation title bar
    private let showScrollToBottomButtonThreshold: CGFloat = 150
    private let loadMoreMessageThreshold = 20
    private let animationDuration: TimeInterval = 0.3
    
    private var ownerUser: UserItem?
    private var quotingMessageId: String?
    private var didInitData = false
    private var isShowingMenu = false
    private var isAppearanceAnimating = true
    private var adjustTableViewContentOffsetWhenInputWrapperHeightChanges = true
    private var didManuallyStoppedTableViewDecelerating = false
    
    private var tapRecognizer: UITapGestureRecognizer!
    private var reportRecognizer: UILongPressGestureRecognizer!
    private var resizeInputRecognizer: ResizeInputWrapperGestureRecognizer!
    private var conversationInputViewController: ConversationInputViewController!
    private var previewDocumentController: UIDocumentInteractionController?
    private var previewDocumentMessageId: String?
    
    private(set) lazy var imagePickerController = ImagePickerController(initialCameraPosition: .rear, cropImageAfterPicked: false, parent: self, delegate: self)
    private lazy var userWindow = UserWindow.instance()
    private lazy var groupWindow = GroupWindow.instance()
    private lazy var userHandleViewController = R.storyboard.chat.user_handle()!
    
    private lazy var strangerTipsView: StrangerTipsView = {
        let view = StrangerTipsView()
        view.frame.size.height = StrangerTipsView.height
        view.blockButton.addTarget(self, action: #selector(blockAction(_:)), for: .touchUpInside)
        view.addContactButton.addTarget(self, action: #selector(addContactAction(_:)), for: .touchUpInside)
        return view
    }()
    
    private var unreadBadgeValue: Int = 0 {
        didSet {
            guard unreadBadgeValue != oldValue else {
                return
            }
            unreadBadgeLabel.isHidden = unreadBadgeValue <= 0
            unreadBadgeLabel.text = unreadBadgeValue <= 99 ? String(unreadBadgeValue) : "99+"
        }
    }
    
    private var maxInputWrapperHeight: CGFloat {
        return AppDelegate.current.window.frame.height
            - navigationBarView.frame.height
            - minInputWrapperTopMargin
    }
    
    override var prefersStatusBarHidden: Bool {
        return statusBarHidden
    }
    
    // MARK: - Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        backgroundImageView.snp.makeConstraints { (make) in
            make.height.equalTo(UIScreen.main.bounds.height)
        }
        tableView.snp.makeConstraints { (make) in
            make.height.equalTo(UIScreen.main.bounds.height)
        }
        showLoading()
        if let swipeBackRecognizer = navigationController?.interactivePopGestureRecognizer {
            tableView.gestureRecognizers?.forEach {
                $0.require(toFail: swipeBackRecognizer)
            }
        }
        if let conversation = dataSource?.conversation {
            titleLabel.text = conversation.getConversationName()
        } else if let ownerUser = ownerUser {
            titleLabel.text = ownerUser.fullName
        }
        
        reportRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(showReportMenuAction))
        reportRecognizer.minimumPressDuration = 2
        titleLabel.isUserInteractionEnabled = true
        titleLabel.addGestureRecognizer(reportRecognizer)
        
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        tapRecognizer.delegate = self
        tableView.addGestureRecognizer(tapRecognizer)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.actionDelegate = self
        tableView.viewController = self
        announcementButton.isHidden = !CommonUserDefault.shared.hasUnreadAnnouncement(conversationId: conversationId)
        dataSource.ownerUser = ownerUser
        dataSource.tableView = tableView
        updateStrangerTipsView()
        inputWrapperView.isHidden = false
        updateNavigationBar()
        NotificationCenter.default.addObserver(self, selector: #selector(conversationDidChange(_:)), name: .ConversationDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(userDidChange(_:)), name: .UserDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuControllerDidShowMenu(_:)), name: UIMenuController.didShowMenuNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuControllerDidHideMenu(_:)), name: UIMenuController.didHideMenuNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(participantDidChange(_:)), name: .ParticipantDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didAddMessageOutOfBounds(_:)), name: ConversationDataSource.didAddMessageOutOfBoundsNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(audioManagerWillPlayNextNode(_:)), name: AudioManager.willPlayNextNotification, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isAppearanceAnimating = true
        if !didInitData {
            didInitData = true
            updateNavigationBarHeightAndTableViewTopInset()
            conversationInputViewController = R.storyboard.chat.input()
            addChild(conversationInputViewController)
            inputWrapperView.addSubview(conversationInputViewController.view)
            conversationInputViewController.view.snp.makeConstraints({ (make) in
                make.edges.equalToSuperview()
            })
            conversationInputViewController.didMove(toParent: self)
            if dataSource.category == .group {
                updateSubtitleAndInputBar()
            } else if let user = ownerUser {
                conversationInputViewController.inputBarView.isHidden = false
                conversationInputViewController.update(opponentUser: user)
            }
            dataSource.initData(completion: finishInitialLoading)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isAppearanceAnimating = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dismissMenu(animated: true)
        isAppearanceAnimating = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        AudioManager.shared.stop()
        if let visibleIndexPaths = tableView.indexPathsForVisibleRows {
            if let lastIndexPath = dataSource?.lastIndexPath, visibleIndexPaths.contains(lastIndexPath), tableView.rectForRow(at: lastIndexPath).origin.y < tableView.contentOffset.y + tableView.frame.height - tableView.contentInset.bottom {
                ConversationViewController.positions[conversationId] = nil
            } else {
                for indexPath in visibleIndexPaths {
                    guard let message = dataSource?.viewModel(for: indexPath)?.message, message.category != MessageCategory.EXT_UNREAD.rawValue else {
                        continue
                    }
                    let rect = tableView.rectForRow(at: indexPath)
                    let offset = tableView.contentInset.top + tableView.contentOffset.y - rect.origin.y
                    let position = Position(messageId: message.messageId, offset: offset)
                    ConversationViewController.positions[conversationId] = position
                    break
                }
            }
        }
        if parent == nil {
            dataSource?.cancelMessageProcessing()
        }
        SendMessageService.shared.sendReadMessages(conversationId: conversationId, force: true)
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateNavigationBarHeightAndTableViewTopInset()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Actions
    @IBAction func profileAction(_ sender: Any) {
        if let dataSource = dataSource, dataSource.category == .group {
            groupWindow.bounds.size.width = view.bounds.width
            groupWindow.updateGroup(conversation: dataSource.conversation).presentView()
        } else if let user = ownerUser, user.isCreatedByMessenger {
            userWindow.bounds.size.width = view.bounds.width
            userWindow.updateUser(user: user).presentView()
        }
    }
    
    @IBAction func announcementAction(_ sender: Any) {
        guard let conversation = dataSource?.conversation, dataSource?.category == .group else {
            return
        }
        groupWindow.updateGroup(conversation: conversation, initialAnnouncementMode: .normal).presentView()
        CommonUserDefault.shared.setHasUnreadAnnouncement(false, forConversationId: conversationId)
        announcementButton.isHidden = true
    }
    
    @IBAction func backAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func scrollToBottomAction(_ sender: Any) {
        unreadBadgeValue = 0
        if let quotingMessageId = quotingMessageId, let indexPath = dataSource?.indexPath(where: { $0.messageId == quotingMessageId }) {
            self.quotingMessageId = nil
            tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
            blinkCellBackground(at: indexPath)
        } else if let quotingMessageId = quotingMessageId, MessageDAO.shared.hasMessage(id: quotingMessageId) {
            self.quotingMessageId = nil
            reloadWithMessageIdAndBlinkTheCell(quotingMessageId, upwards: true)
        } else {
            dataSource?.scrollToFirstUnreadMessageOrBottom()
        }
    }
    
    @objc func resizeInputWrapperAction(_ recognizer: ResizeInputWrapperGestureRecognizer) {
        let location = recognizer.location(in: inputWrapperView)
        let verticalVelocity = recognizer.velocity(in: view).y
        let regularInputWrapperHeight = conversationInputViewController.regularHeight
        var inputWrapperHeight: CGFloat {
            get {
                return inputWrapperHeightConstraint.constant
            }
            set {
                inputWrapperHeightConstraint.constant = newValue
            }
        }
        switch recognizer.state {
        case .began:
            recognizer.inputWrapperHeightWhenBegan = inputWrapperHeight
        case .changed:
            let shouldMoveDown = verticalVelocity > 0 && location.y > 0
            let canMoveUp = !conversationInputViewController.textView.isFirstResponder
                || inputWrapperHeight < conversationInputViewController.regularHeight
            let shouldMoveUp = canMoveUp
                && location.y < 0
                && verticalVelocity < 0
                && recognizer.hasMovedInputWrapperDuringChangedState
            if shouldMoveDown || shouldMoveUp {
                recognizer.hasMovedInputWrapperDuringChangedState = true
                var newHeight = inputWrapperHeight - recognizer.translation(in: view).y
                if newHeight < conversationInputViewController.minimizedHeight {
                    newHeight = conversationInputViewController.minimizedHeight
                    if shouldMoveDown && conversationInputViewController.view.backgroundColor == .clear {
                        conversationInputViewController.view.backgroundColor = .white
                    }
                }
                if conversationInputViewController.isMaximizable {
                    newHeight = min(newHeight, maxInputWrapperHeight)
                } else {
                    newHeight = min(newHeight, regularInputWrapperHeight)
                }
                updateNavigationBarPositionWithInputWrapperViewHeight(oldHeight: inputWrapperHeight, newHeight: newHeight)
                inputWrapperHeight = newHeight
                view.layoutIfNeeded()
            }
            recognizer.setTranslation(.zero, in: view)
        case .ended:
            let shouldResize = abs(inputWrapperHeight - recognizer.inputWrapperHeightWhenBegan) > 1
                && !conversationInputViewController.textView.isFirstResponder
            if shouldResize {
                if verticalVelocity >= 0 {
                    if inputWrapperHeight > regularInputWrapperHeight {
                        conversationInputViewController.setPreferredContentHeightAnimated(.regular)
                    } else {
                        conversationInputViewController.dismissCustomInput(minimize: true)
                    }
                } else {
                    if inputWrapperHeight > conversationInputViewController.regularHeight {
                        conversationInputViewController.setPreferredContentHeightAnimated(.maximized)
                    } else {
                        conversationInputViewController.setPreferredContentHeightAnimated(.regular)
                    }
                }
            }
        default:
            break
        }
    }
    
    @objc func blockAction(_ sender: Any) {
        guard let userId = ownerUser?.userId else {
            return
        }
        strangerTipsView.blockButton.isBusy = true
        UserAPI.shared.blockUser(userId: userId) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.strangerTipsView.blockButton.isBusy = false
            switch result {
            case .success(let userResponse):
                weakSelf.updateOwnerUser(withUserResponse: userResponse, updateDatabase: true)
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
    @objc func addContactAction(_ sender: Any) {
        guard let user = ownerUser else {
            return
        }
        strangerTipsView.addContactButton.isBusy = true
        UserAPI.shared.addFriend(userId: user.userId, full_name: user.fullName) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.strangerTipsView.addContactButton.isBusy = false
            switch result {
            case .success(let userResponse):
                weakSelf.updateOwnerUser(withUserResponse: userResponse, updateDatabase: true)
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
    @objc func tapAction(_ recognizer: UIGestureRecognizer) {
        if conversationInputViewController.audioViewController.hideLongPressHint() {
            return
        }
        if isShowingMenu {
            dismissMenu(animated: true)
            return
        }
        if let indexPath = tableView.indexPathForRow(at: recognizer.location(in: tableView)), let cell = tableView.cellForRow(at: indexPath) as? MessageCell, cell.contentFrame.contains(recognizer.location(in: cell)), let viewModel = dataSource?.viewModel(for: indexPath) {
            let message = viewModel.message
            let isImageOrVideo = message.category.hasSuffix("_IMAGE") || message.category.hasSuffix("_VIDEO")
            let mediaStatusIsReady = message.mediaStatus == MediaStatus.DONE.rawValue || message.mediaStatus == MediaStatus.READ.rawValue
            if message.category.hasSuffix("_TEXT"), let cell = cell as? QuoteTextMessageCell, cell.quoteBackgroundImageView.frame.contains(recognizer.location(in: cell)), let quoteMessageId = viewModel.message.quoteMessageId {
                if let indexPath = dataSource?.indexPath(where: { $0.messageId == quoteMessageId }) {
                    quotingMessageId = message.messageId
                    tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
                    blinkCellBackground(at: indexPath)
                } else if MessageDAO.shared.hasMessage(id: quoteMessageId) {
                    quotingMessageId = message.messageId
                    reloadWithMessageIdAndBlinkTheCell(quoteMessageId, upwards: false)
                }
            } else if message.category.hasSuffix("_AUDIO"), message.mediaStatus == MediaStatus.DONE.rawValue || message.mediaStatus == MediaStatus.READ.rawValue {
                if AudioManager.shared.playingMessage?.messageId == message.messageId, AudioManager.shared.player?.status == .playing {
                    AudioManager.shared.pause()
                } else {
                    (cell as? AudioMessageCell)?.updateUnreadStyle()
                    AudioManager.shared.play(message: message)
                }
            } else if (isImageOrVideo && mediaStatusIsReady) || message.category.hasSuffix("_LIVE"), let item = GalleryItem(message: message), let cell = cell as? PhotoRepresentableMessageCell {
                adjustTableViewContentOffsetWhenInputWrapperHeightChanges = false
                conversationInputViewController.dismiss()
                adjustTableViewContentOffsetWhenInputWrapperHeightChanges = true
                if let galleryViewController = UIApplication.homeContainerViewController?.galleryViewController {
                    galleryViewController.conversationId = conversationId
                    galleryViewController.show(item: item, from: cell)
                }
            } else if message.category.hasSuffix("_DATA"), let viewModel = viewModel as? DataMessageViewModel, let cell = cell as? DataMessageCell {
                if viewModel.mediaStatus == MediaStatus.DONE.rawValue || viewModel.mediaStatus == MediaStatus.READ.rawValue {
                    conversationInputViewController.dismiss()
                    UIApplication.homeContainerViewController?.pipController?.pauseAction(self)
                    openDocumentAction(message: message)
                } else {
                    attachmentLoadingCellDidSelectNetworkOperation(cell)
                }
            } else if message.category.hasSuffix("_CONTACT"), let shareUserId = message.sharedUserId {
                conversationInputViewController.dismiss()
                if shareUserId == AccountAPI.shared.accountUserId {
                    guard let account = AccountAPI.shared.account else {
                        return
                    }
                    UserWindow.instance().updateUser(user: UserItem.createUser(from: account)).presentView()
                } else if let user = UserDAO.shared.getUser(userId: shareUserId), user.isCreatedByMessenger {
                    UserWindow.instance().updateUser(user: user).presentView()
                }
            } else if message.category == MessageCategory.EXT_ENCRYPTION.rawValue {
                conversationInputViewController.dismiss()
                open(url: .aboutEncryption)
            } else if message.category == MessageCategory.SYSTEM_ACCOUNT_SNAPSHOT.rawValue {
                conversationInputViewController.dismiss()
                DispatchQueue.global().async { [weak self] in
                    guard let assetId = message.snapshotAssetId, let snapshotId = message.snapshotId, let asset = AssetDAO.shared.getAsset(assetId: assetId), let snapshot = SnapshotDAO.shared.getSnapshot(snapshotId: snapshotId) else {
                        return
                    }
                    DispatchQueue.main.async {
                        self?.navigationController?.pushViewController(TransactionViewController.instance(asset: asset, snapshot: snapshot), animated: true)
                    }
                }
            } else if message.category == MessageCategory.APP_CARD.rawValue, let action = message.appCard?.action {
                conversationInputViewController.dismiss()
                openAction(action: action.absoluteString)
            } else {
                conversationInputViewController.dismiss()
            }
        } else {
            conversationInputViewController.dismiss()
        }
    }
    
    @objc func showReportMenuAction() {
        guard !self.conversationId.isEmpty else {
            return
        }
        
        let conversationId = self.conversationId
        let alc = UIAlertController(title: Localized.REPORT_TITLE, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.REPORT_BUTTON, style: .default, handler: { [weak self](_) in
            self?.report(conversationId: conversationId)
        }))
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        self.present(alc, animated: true, completion: nil)
    }
    
    // MARK: - Callbacks
    @objc func conversationDidChange(_ sender: Notification) {
        guard let change = sender.object as? ConversationChange, change.conversationId == conversationId else {
            return
        }
        switch change.action {
        case let .updateGroupIcon(iconUrl):
            avatarImageView?.setGroupImage(with: iconUrl)
        case .update:
            hideLoading()
        case let .updateConversation(conversation):
            if !conversation.name.isEmpty {
                titleLabel.text = conversation.name
                dataSource?.conversation.name = conversation.name
            }
            dataSource?.conversation.announcement = conversation.announcement
            announcementButton.isHidden = !CommonUserDefault.shared.hasUnreadAnnouncement(conversationId: conversationId)
            hideLoading()
        case .startedUpdateConversation:
            showLoading()
        default:
            break
        }
    }
    
    @objc func userDidChange(_ sender: Notification) {
        if let userResponse = sender.object as? UserResponse, userResponse.userId == self.ownerUser?.userId {
            updateOwnerUser(withUserResponse: userResponse, updateDatabase: false)
        } else if let user = sender.object as? UserItem, user.userId == self.ownerUser?.userId {
            self.ownerUser = user
            updateNavigationBar()
            conversationInputViewController.update(opponentUser: user)
            updateStrangerTipsView()
        }
        hideLoading()
        dataSource?.ownerUser = ownerUser
    }
    
    @objc func menuControllerDidShowMenu(_ notification: Notification) {
        isShowingMenu = true
    }
    
    @objc func menuControllerDidHideMenu(_ notification: Notification) {
        isShowingMenu = false
        conversationInputViewController.textView.overrideNext = nil
    }
    
    @objc func participantDidChange(_ notification: Notification) {
        guard didInitData, let conversationId = notification.object as? String, conversationId == self.conversationId else {
            return
        }
        updateSubtitleAndInputBar()
    }
    
    @objc func didAddMessageOutOfBounds(_ notification: Notification) {
        guard let count = notification.object as? Int else {
            return
        }
        unreadBadgeValue += count
    }
    
    @objc func audioManagerWillPlayNextNode(_ notification: Notification) {
        guard !tableView.isTracking else {
            return
        }
        guard let conversationId = notification.userInfo?[AudioManager.conversationIdUserInfoKey] as? String, conversationId == dataSource.conversationId else {
            return
        }
        guard let messageId = notification.userInfo?[AudioManager.messageIdUserInfoKey] as? String else {
            return
        }
        if let indexPath = dataSource.indexPath(where: { $0.messageId == messageId }) {
            let cellFrame = tableView.convert(tableView.rectForRow(at: indexPath), to: view)
            let isCellInvisible = cellFrame.minY < navigationBarView.frame.height
                || cellFrame.maxY > view.bounds.height - inputWrapperView.frame.height
            if isCellInvisible {
                tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
            }
        } else {
            dataSource.scrollToBottomAndReload(initialMessageId: messageId, completion: nil)
        }
    }
    
    // MARK: - Interface
    func updateInputWrapper(for preferredContentHeight: CGFloat, animated: Bool) {
        let oldHeight = inputWrapperHeightConstraint.constant
        let newHeight = min(maxInputWrapperHeight, preferredContentHeight)
        inputWrapperHeightConstraint.constant = newHeight
        var bottomInset = newHeight
        tableView.scrollIndicatorInsets.bottom = bottomInset
        bottomInset += MessageViewModel.bottomSeparatorHeight
        if animated {
            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationDuration(0.5)
            UIView.setAnimationCurve(.overdamped)
        }
        updateNavigationBarPositionWithInputWrapperViewHeight(oldHeight: oldHeight, newHeight: newHeight)
        tableView.setContentInsetBottom(bottomInset, automaticallyAdjustContentOffset: adjustTableViewContentOffsetWhenInputWrapperHeightChanges)
        view.layoutIfNeeded()
        if animated {
            UIView.commitAnimations()
        }
    }
    
    func inputTextViewDidChange(_ textView: UITextView) {
        userHandleViewController.reload(with: textView.text) { (hasContent) in
            self.setUserHandleHidden(!hasContent)
        }
    }
    
    func inputUserHandle(with user: User) {
        let text = "@" + user.identityNumber + " "
        conversationInputViewController.textView.text = text
        userHandleViewController.reload(with: text) { (hasContent) in
            self.setUserHandleHidden(true)
        }
    }
    
    func documentAction() {
        let vc = UIDocumentPickerViewController(documentTypes: ["public.item", "public.content"], in: .import)
        vc.delegate = self
        vc.modalPresentationStyle = .formSheet
        present(vc, animated: true, completion: nil)
    }
    
    func transferAction() {
        guard let user = ownerUser else {
            return
        }
        let viewController: UIViewController
        if AccountAPI.shared.account?.has_pin ?? false {
            viewController = TransferOutViewController.instance(asset: nil, type: .contact(user))
        } else {
            viewController = WalletPasswordViewController.instance(dismissTarget: .transfer(user: user))
        }
        navigationController?.pushViewController(viewController, animated: true)
    }

    func contactAction() {
        let vc = ContactSelectorViewController.instance(ownerUser: ownerUser, conversation: dataSource.conversation)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func callAction() {
        guard let ownerUser = dataSource.ownerUser else {
            return
        }
        CallManager.shared.checkPreconditionsAndCallIfPossible(opponentUser: ownerUser)
    }

    func pickPhotoOrVideoAction() {
        PHPhotoLibrary.checkAuthorization { [weak self](authorized) in
            guard authorized, let weakSelf = self else {
                return
            }
            let picker = PhotoAssetPickerNavigationController.instance(pickerDelegate: weakSelf)
            weakSelf.present(picker, animated: true, completion: nil)
        }
    }
    
    func openOpponentApp(_ app: App) {
        guard !conversationId.isEmpty else {
            return
        }
        if let appUser = ownerUser {
            ConcurrentJobQueue.shared.addJob(job: RefreshUserJob(userIds: [appUser.userId]))
        }
        UIApplication.logEvent(eventName: "open_app", parameters: ["source": "Conversation", "identityNumber": app.appNumber])
        WebViewController.presentInstance(with: .init(conversationId: conversationId, app: app), asChildOf: self)
    }
    
    func handleMessageRecalling(messageId: String) {
        guard isViewLoaded else {
            return
        }
        if messageId == previewDocumentMessageId {
            previewDocumentController?.dismissPreview(animated: true)
            previewDocumentController?.dismissMenu(animated: true)
            previewDocumentController = nil
            previewDocumentMessageId = nil
        }
    }
    
    // MARK: - Class func
    class func instance(conversation: ConversationItem, highlight: ConversationDataSource.Highlight? = nil) -> ConversationViewController {
        let vc = Storyboard.chat.instantiateViewController(withIdentifier: "conversation") as! ConversationViewController
        let dataSource = ConversationDataSource(conversation: conversation, highlight: highlight)
        if dataSource.category == .contact {
            vc.ownerUser = UserDAO.shared.getUser(userId: dataSource.conversation.ownerId)
        }
        vc.dataSource = dataSource
        return vc
    }
    
    class func instance(ownerUser: UserItem) -> ConversationViewController {
        let vc = Storyboard.chat.instantiateViewController(withIdentifier: "conversation") as! ConversationViewController
        vc.ownerUser = ownerUser
        let conversationId = ConversationDAO.shared.makeConversationId(userId: AccountAPI.shared.accountUserId, ownerUserId: ownerUser.userId)
        let conversation = ConversationDAO.shared.getConversation(conversationId: conversationId)
            ?? ConversationItem(ownerUser: ownerUser)
        vc.dataSource = ConversationDataSource(conversation: conversation)
        return vc
    }
    
}

// MARK: - UIGestureRecognizerDelegate
extension ConversationViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer != resizeInputRecognizer
            || inputWrapperHeightConstraint.constant > conversationInputViewController.minimizedHeight
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer != tapRecognizer || isShowingMenu {
            return true
        }
        if let view = touch.view as? TextMessageLabel {
            return !view.canResponseTouch(at: touch.location(in: view))
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return !(gestureRecognizer == tapRecognizer || otherGestureRecognizer == tapRecognizer)
    }
    
}

// MARK: - UITableViewDataSource
extension ConversationViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource?.viewModels(for: section)?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = dataSource?.viewModel(for: indexPath) else {
            return self.tableView.dequeueReusableCell(withReuseId: .unknown, for: indexPath)
        }
        let cell = self.tableView.dequeueReusableCell(withMessage: viewModel.message, for: indexPath)
        if let cell = cell as? MessageCell {
            UIView.performWithoutAnimation {
                cell.render(viewModel: viewModel)
            }
        }
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource?.dates.count ?? 0
    }
    
}

// MARK: - ConversationTableViewActionDelegate
extension ConversationViewController: ConversationTableViewActionDelegate {
    
    func conversationTableViewCanBecomeFirstResponder(_ tableView: ConversationTableView) -> Bool {
        return !conversationInputViewController.textView.isFirstResponder
    }
    
    func conversationTableViewLongPressWillBegan(_ tableView: ConversationTableView) {
        conversationInputViewController.textView.overrideNext = tableView
    }
    
    func conversationTableView(_ tableView: ConversationTableView, hasActionsforIndexPath indexPath: IndexPath) -> Bool {
        guard let message = dataSource?.viewModel(for: indexPath)?.message else {
            return false
        }
        return !message.allowedActions.isEmpty
    }
    
    func conversationTableView(_ tableView: ConversationTableView, canPerformAction action: Selector, forIndexPath indexPath: IndexPath) -> Bool {
        guard let message = dataSource?.viewModel(for: indexPath)?.message else {
            return false
        }
        return message.allowedActions.contains(action)
    }
    
    func conversationTableView(_ tableView: ConversationTableView, didSelectAction action: ConversationTableView.Action, forIndexPath indexPath: IndexPath) {
        guard let viewModel = dataSource?.viewModel(for: indexPath) else {
            return
        }
        let message = viewModel.message
        switch action {
        case .copy:
            if message.category.hasSuffix("_TEXT") {
                UIPasteboard.general.string = message.content
            }
        case .delete:
            conversationInputViewController.textView.resignFirstResponder()
            let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            if message.canRecall() {
                controller.addAction(UIAlertAction(title: Localized.ACTION_DELETE_EVERYONE, style: .destructive, handler: { (_) in
                    if CommonUserDefault.shared.isRecallTips {
                        self.deleteForEveryone(viewModel: viewModel)
                    } else {
                        self.showRecallTips(viewModel: viewModel)
                    }
                }))
            }
            controller.addAction(UIAlertAction(title: Localized.ACTION_DELETE_ME, style: .destructive, handler: { (_) in
                self.deleteForMe(viewModel: viewModel)
            }))
            controller.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
            self.present(controller, animated: true, completion: nil)
        case .forward:
            conversationInputViewController.audioViewController.cancelIfRecording()
            let vc = MessageReceiverViewController.instance(content: .message(message))
            navigationController?.pushViewController(vc, animated: true)
        case .reply:
            conversationInputViewController.quote = (message, viewModel.thumbnail)
        case .add:
            if message.category.hasSuffix("_STICKER"), let stickerId = message.stickerId {
                StickerAPI.shared.addSticker(stickerId: stickerId, completion: { (result) in
                    switch result {
                    case let .success(sticker):
                        DispatchQueue.global().async {
                            StickerDAO.shared.insertOrUpdateFavoriteSticker(sticker: sticker)
                            showAutoHiddenHud(style: .notification, text: Localized.TOAST_ADDED)
                        }
                    case let .failure(error):
                        showAutoHiddenHud(style: .error, text: error.localizedDescription)
                    }
                })
            } else {
                navigationController?.pushViewController(StickerAddViewController.instance(message: message), animated: true)
            }
        }
    }
}

// MARK: - UITableViewDelegate
extension ConversationViewController: UITableViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateAccessoryButtons(animated: !isAppearanceAnimating)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        didManuallyStoppedTableViewDecelerating = false
        UIView.animate(withDuration: animationDuration) {
            self.tableView.setFloatingHeaderViewsHidden(false, animated: false)
            self.dismissMenu(animated: false)
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            didManuallyStoppedTableViewDecelerating = true
            tableView.setFloatingHeaderViewsHidden(true, animated: true, delay: 0.5)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if !tableView.isTracking && !didManuallyStoppedTableViewDecelerating {
            tableView.setFloatingHeaderViewsHidden(true, animated: true)
        }
    }
    
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        return false
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        DispatchQueue.main.async {
            self.tableView.setFloatingHeaderViewsHidden(true, animated: true, delay: 1)
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let dataSource = dataSource else {
            return
        }
        if indexPath.section == 0 && indexPath.row <= loadMoreMessageThreshold {
            dataSource.loadMoreAboveIfNeeded()
        }
        if let lastIndexPath = dataSource.lastIndexPath, indexPath.section == lastIndexPath.section, indexPath.row >= lastIndexPath.row - loadMoreMessageThreshold {
            dataSource.loadMoreBelowIfNeeded()
        }
        let messageId = dataSource.viewModel(for: indexPath)?.message.messageId
        if messageId == dataSource.firstUnreadMessageId || cell is UnreadHintMessageCell {
            unreadBadgeValue = 0
            dataSource.firstUnreadMessageId = nil
        }
        if let messageId = messageId, messageId == quotingMessageId {
            quotingMessageId = nil
        }
        if let viewModel = dataSource.viewModel(for: indexPath) as? AttachmentLoadingViewModel, viewModel.automaticallyLoadsAttachment {
            viewModel.beginAttachmentLoading(isTriggeredByUser: false)
            (cell as? AttachmentLoadingMessageCell)?.updateOperationButtonStyle()
        }
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let viewModel = dataSource?.viewModel(for: indexPath) else {
            return
        }
        if let viewModel = viewModel as? AttachmentLoadingViewModel {
            viewModel.cancelAttachmentLoading(isTriggeredByUser: false)
        }
        if viewModel.message.messageId == quotingMessageId, let lastVisibleIndexPath = tableView.indexPathsForVisibleRows?.last, lastVisibleIndexPath.section > indexPath.section || (lastVisibleIndexPath.section == indexPath.section && lastVisibleIndexPath.row > indexPath.row) {
            quotingMessageId = nil
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let viewModel = dataSource?.viewModel(for: indexPath) else {
            return 44
        }
        if viewModel.cellHeight.isNaN || viewModel.cellHeight < 1 {
            return 44
        } else {
            return viewModel.cellHeight
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return ConversationDateHeaderView.height
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: ConversationTableView.ReuseId.header.rawValue) as! ConversationDateHeaderView
        if let date = dataSource?.dates[section] {
            header.label.text = DateFormatter.yyyymmdd.date(from: date)?.timeDayAgo()
        }
        return header
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        return nil
    }
    
}

// MARK: - DetailInfoMessageCellDelegate
extension ConversationViewController: DetailInfoMessageCellDelegate {
    
    func detailInfoMessageCellDidSelectFullname(_ cell: DetailInfoMessageCell) {
        guard let indexPath = tableView.indexPath(for: cell), let message = dataSource?.viewModel(for: indexPath)?.message, let user = UserDAO.shared.getUser(userId: message.userId) else {
            return
        }
        userWindow.updateUser(user: user).presentView()
    }
    
}

// MARK: - AppButtonGroupMessageCellDelegate
extension ConversationViewController: AppButtonGroupMessageCellDelegate {
    
    func appButtonGroupMessageCell(_ cell: AppButtonGroupMessageCell, didSelectActionAt index: Int) {
        guard let indexPath = tableView.indexPath(for: cell), let appButtons = dataSource?.viewModel(for: indexPath)?.message.appButtons, index < appButtons.count else {
            return
        }
        openAction(action: appButtons[index].action)
    }
    
}

// MARK: - AttachmentLoadingMessageCellDelegate
extension ConversationViewController: AttachmentLoadingMessageCellDelegate {
    
    func attachmentLoadingCellDidSelectNetworkOperation(_ cell: UITableViewCell & AttachmentLoadingMessageCell) {
        guard let indexPath = tableView.indexPath(for: cell), let viewModel = dataSource?.viewModel(for: indexPath) as? MessageViewModel & AttachmentLoadingViewModel else {
            return
        }
        switch viewModel.operationButtonStyle {
        case .download, .upload:
            viewModel.beginAttachmentLoading(isTriggeredByUser: true)
        case .busy:
            viewModel.cancelAttachmentLoading(isTriggeredByUser: true)
        case .expired, .finished:
            break
        }
        cell.updateOperationButtonStyle()
    }
    
}

// MARK: - CoreTextLabelDelegate
extension ConversationViewController: CoreTextLabelDelegate {
    
    func coreTextLabel(_ label: CoreTextLabel, didSelectURL url: URL) {
        guard !openUrlOutsideApplication(url) else {
            return
        }
        open(url: url)
    }
    
    func coreTextLabel(_ label: CoreTextLabel, didLongPressOnURL url: URL) {
        let alert = UIAlertController(title: url.absoluteString, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: Localized.CHAT_MESSAGE_OPEN_URL, style: .default, handler: { [weak self](_) in
            self?.open(url: url)
        }))
        alert.addAction(UIAlertAction(title: Localized.CHAT_MESSAGE_MENU_COPY, style: .default, handler: { (_) in
            UIPasteboard.general.string = url.absoluteString
            showAutoHiddenHud(style: .notification, text: Localized.TOAST_COPIED)

        }))
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
}

// MARK: - ImagePickerControllerDelegate
extension ConversationViewController: ImagePickerControllerDelegate {
    
    func imagePickerController(_ controller: ImagePickerController, didPickImage image: UIImage) {
        let previewViewController = AssetSendViewController.instance(image: image, dataSource: dataSource)
        navigationController?.pushViewController(previewViewController, animated: true)
    }
    
}

// MARK: - UIDocumentPickerDelegate
extension ConversationViewController: UIDocumentPickerDelegate {
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard urls.count > 0 else {
            return
        }
        documentPicker(controller, didPickDocumentAt: urls[0])
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        let previewViewController = FileSendViewController.instance(documentUrl: url, dataSource: dataSource)
        navigationController?.pushViewController(previewViewController, animated: true)
    }
    
}

// MARK: - UIDocumentInteractionControllerDelegate
extension ConversationViewController: UIDocumentInteractionControllerDelegate {
    
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
        previewDocumentController = nil
        previewDocumentMessageId = nil
    }
    
}

// MARK: - GalleryViewControllerDelegate
extension ConversationViewController: GalleryViewControllerDelegate {
    
    func galleryViewController(_ viewController: GalleryViewController, cellFor item: GalleryItem) -> GalleryTransitionSource? {
        return visiblePhotoRepresentableCell(of: item.messageId)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, willShow item: GalleryItem) {
        guard UIApplication.homeContainerViewController?.pipController?.item != item else {
            return
        }
        setCell(ofMessageId: item.messageId, contentViewHidden: true)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, didShow item: GalleryItem) {
        setCell(ofMessageId: item.messageId, contentViewHidden: false)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, willDismiss item: GalleryItem) {
        setCell(ofMessageId: item.messageId, contentViewHidden: true)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, didCancelDismissalFor item: GalleryItem) {
        setCell(ofMessageId: item.messageId, contentViewHidden: false)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, didDismiss item: GalleryItem, relativeOffset: CGFloat?) {
        if let offset = relativeOffset, let indexPath = dataSource?.indexPath(where: { $0.messageId == item.messageId }), let cell = tableView.cellForRow(at: indexPath) as? PhotoRepresentableMessageCell {
            (dataSource.viewModel(for: indexPath) as? PhotoRepresentableMessageViewModel)?.layoutPosition = .relativeOffset(offset)
            cell.contentImageWrapperView.position = .relativeOffset(offset)
            cell.contentImageWrapperView.layoutIfNeeded()
        }
        setCell(ofMessageId: item.messageId, contentViewHidden: false)
    }
    
}

// MARK: - PhotoAssetPickerDelegate
extension ConversationViewController: PhotoAssetPickerDelegate {

    func pickerController(_ picker: PickerViewController, contentOffset: CGPoint, didFinishPickingMediaWithAsset asset: PHAsset) {
        navigationController?.pushViewController(AssetSendViewController.instance(asset: asset, dataSource: dataSource), animated: true)
    }
    
}

// MARK: - UI Related Helpers
extension ConversationViewController {
    
    private func updateNavigationBar() {
        if dataSource.category == .group {
            let conversation = dataSource.conversation
            titleLabel.text = conversation.name
            avatarImageView.setGroupImage(with: conversation.iconUrl)
        } else if let user = ownerUser {
            subtitleLabel.text = user.identityNumber
            titleLabel.text = user.fullName
            avatarImageView.setImage(with: user)
        }
    }
    
    private func updateSubtitleAndInputBar() {
        let conversationId = dataSource.conversationId
        dataSource.queue.async { [weak self] in
            let isParticipant = ParticipantDAO.shared.userId(AccountAPI.shared.accountUserId, isParticipantOfConversationId: conversationId)
            if isParticipant {
                let count = ParticipantDAO.shared.getParticipantCount(conversationId: conversationId)
                DispatchQueue.main.sync {
                    guard let weakSelf = self else {
                        return
                    }
                    weakSelf.conversationInputViewController.deleteConversationButton.isHidden = true
                    weakSelf.conversationInputViewController.inputBarView.isHidden = false
                    weakSelf.subtitleLabel.text = Localized.GROUP_SECTION_TITLE_MEMBERS(count: count)
                }
            } else {
                DispatchQueue.main.sync {
                    guard let weakSelf = self else {
                        return
                    }
                    weakSelf.conversationInputViewController.deleteConversationButton.isHidden = false
                    weakSelf.conversationInputViewController.inputBarView.isHidden = false
                    weakSelf.subtitleLabel.text = Localized.GROUP_REMOVE_TITLE
                }
            }
        }
    }

    private func updateNavigationBarPositionWithInputWrapperViewHeight(oldHeight: CGFloat, newHeight: CGFloat) {
        let diff = newHeight - oldHeight
        if conversationInputViewController.isMaximizable && newHeight > conversationInputViewController.regularHeight {
            let top = navigationBarTopConstraint.constant + diff
            let maxTop = navigationBarView.frame.height
            let navigationBarTop = min(maxTop, max(0, top))
            navigationBarTopConstraint.constant = navigationBarTop
            tableView.contentInset.top = max(view.safeAreaInsets.top, navigationBarView.frame.height - navigationBarTop)
            tableView.scrollIndicatorInsets.top = tableView.contentInset.top
            if !statusBarHidden {
                UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState], animations: {
                    self.statusBarHidden = true
                }, completion: nil)
            }
        } else {
            navigationBarTopConstraint.constant = 0
            tableView.contentInset.top = navigationBarView.frame.height
            tableView.scrollIndicatorInsets.top = tableView.contentInset.top
            if statusBarHidden {
                UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState], animations: {
                    self.statusBarHidden = false
                }, completion: nil)
            }
        }
    }
    
    private func updateOwnerUser(withUserResponse userResponse: UserResponse, updateDatabase: Bool) {
        if updateDatabase {
            UserDAO.shared.updateUsers(users: [userResponse], sendNotificationAfterFinished: false)
        }
        let user = UserItem.createUser(from: userResponse)
        conversationInputViewController.update(opponentUser: user)
        self.ownerUser = user
        updateNavigationBar()
        updateStrangerTipsView()
    }
    
    private func updateAccessoryButtons(animated: Bool) {
        let position = tableView.contentSize.height - tableView.contentOffset.y - tableView.bounds.height
        let didReachThreshold = position > showScrollToBottomButtonThreshold
        let shouldShowScrollToBottomButton = didReachThreshold || !dataSource.didLoadLatestMessage
        if scrollToBottomWrapperView.alpha < 0.1 && shouldShowScrollToBottomButton {
            scrollToBottomWrapperHeightConstraint.constant = 48
            if animated {
                UIView.beginAnimations(nil, context: nil)
                UIView.setAnimationDuration(animationDuration)
            }
            scrollToBottomWrapperView.alpha = 1
            if animated {
                view.layoutIfNeeded()
                UIView.commitAnimations()
            }
        } else if scrollToBottomWrapperView.alpha > 0.9 && !shouldShowScrollToBottomButton {
            scrollToBottomWrapperHeightConstraint.constant = 4
            if animated {
                UIView.beginAnimations(nil, context: nil)
                UIView.setAnimationDuration(animationDuration)
            }
            scrollToBottomWrapperView.alpha = 0
            if animated {
                view.layoutIfNeeded()
                UIView.commitAnimations()
            }
            unreadBadgeValue = 0
            dataSource?.firstUnreadMessageId = nil
        }
    }
    
    private func dismissMenu(animated: Bool) {
        guard UIMenuController.shared.isMenuVisible else {
            return
        }
        UIMenuController.shared.setMenuVisible(false, animated: animated)
    }
    
    private func updateStrangerTipsView() {
        DispatchQueue.global().async { [weak self] in
            if let ownerUser = self?.ownerUser, ownerUser.relationship == Relationship.STRANGER.rawValue, !MessageDAO.shared.hasSentMessage(toUserId: ownerUser.userId) {
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        return
                    }
                    weakSelf.tableView.tableFooterView = weakSelf.strangerTipsView
                }
            } else {
                DispatchQueue.main.async {
                    self?.tableView.tableFooterView = nil
                }
            }
        }
    }
    
    private func updateNavigationBarHeightAndTableViewTopInset() {
        titleViewTopConstraint.constant = max(20, view.safeAreaInsets.top)
        tableView.contentInset.top = titleViewTopConstraint.constant + titleViewHeightConstraint.constant
        tableView.scrollIndicatorInsets.top = tableView.contentInset.top
    }
    
    private func blinkCellBackground(at indexPath: IndexPath) {
        let animation = { (indexPath: IndexPath) in
            guard let cell = self.tableView.cellForRow(at: indexPath) as? DetailInfoMessageCell else {
                return
            }
            cell.updateAppearance(highlight: true, animated: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                cell.updateAppearance(highlight: false, animated: true)
            })
        }
        if let visibleIndexPaths = tableView.indexPathsForVisibleRows, visibleIndexPaths.contains(indexPath) {
            animation(indexPath)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                animation(indexPath)
            })
        }
    }
    
    private func setCell(ofMessageId id: String?, contentViewHidden hidden: Bool) {
        guard let id = id, let cell = visiblePhotoRepresentableCell(of: id) else {
            return
        }
        var contentViews = [
            cell.contentImageView,
            cell.shadowImageView,
            cell.timeLabel,
            cell.statusImageView
        ]
        if let cell = cell as? AttachmentExpirationHintingMessageCell {
            contentViews.append(cell.operationButton)
        }
        if let cell = cell as? VideoMessageCell {
            contentViews.append(cell.lengthLabel)
        }
        if let cell = cell as? LiveMessageCell {
            contentViews.append(cell.badgeView)
            contentViews.append(cell.playButton)
        }
        contentViews.forEach {
            $0.isHidden = hidden
        }
    }
    
    private func frameOfPhotoRepresentableCell(_ cell: PhotoRepresentableMessageCell) -> CGRect {
        var rect = cell.contentImageView.convert(cell.contentImageView.bounds, to: view)
        if UIApplication.shared.statusBarFrame.height == StatusBarHeight.inCall {
            rect.origin.y += (StatusBarHeight.inCall - StatusBarHeight.normal)
        }
        return rect
    }
    
    private func visiblePhotoRepresentableCell(of messageId: String) -> PhotoRepresentableMessageCell? {
        for case let cell as PhotoRepresentableMessageCell in tableView.visibleCells {
            if cell.viewModel?.message.messageId == messageId {
                return cell
            }
        }
        return nil
    }
    
    private func loadUserHandleAsChildIfNeeded() {
        guard userHandleViewController.parent == nil else {
            return
        }
        addChild(userHandleViewController)
        view.insertSubview(userHandleViewController.view, belowSubview: inputWrapperView)
        userHandleViewController.view.snp.makeConstraints { (make) in
            make.top.equalTo(navigationBarView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(inputWrapperView.snp.top)
        }
        userHandleViewController.didMove(toParent: self)
    }
    
    private func setUserHandleHidden(_ hidden: Bool) {
        if hidden {
            if userHandleViewController.isViewLoaded {
                userHandleViewController.view.isHidden = true
            }
            inputWrapperTopShadowView.alpha = 0
        } else {
            loadUserHandleAsChildIfNeeded()
            userHandleViewController.view.isHidden = false
            inputWrapperTopShadowView.alpha = 1
        }
    }
    
}

// MARK: - Helpers
extension ConversationViewController {
    
    private func finishInitialLoading() {
        resizeInputRecognizer = ResizeInputWrapperGestureRecognizer(target: self, action: #selector(resizeInputWrapperAction(_:)))
        if let popRecognizer = navigationController?.interactivePopGestureRecognizer {
            resizeInputRecognizer.require(toFail: popRecognizer)
        }
        resizeInputRecognizer.delegate = self
        tableView.addGestureRecognizer(resizeInputRecognizer)
        
        updateAccessoryButtons(animated: false)
        conversationInputViewController.finishLoading()
        if dataSource.category == .group {
            let users = UserDAO.shared.getAppUsers(inConversationOf: conversationId)
            userHandleViewController.users = users
            let keyword: String = conversationInputViewController.textView.text
            userHandleViewController.reload(with: keyword) { (hasContent) in
                self.setUserHandleHidden(!hasContent)
            }
        }
        hideLoading()
    }
    
    private func openDocumentAction(message: MessageItem) {
        guard let mediaUrl = message.mediaUrl else {
            return
        }
        let url = MixinFile.url(ofChatDirectory: .files, filename: mediaUrl)
        guard FileManager.default.fileExists(atPath: url.path)  else {
            return
        }
        previewDocumentController = UIDocumentInteractionController(url: url)
        previewDocumentController?.delegate = self
        if !(previewDocumentController?.presentPreview(animated: true) ?? false) {
            previewDocumentController?.presentOpenInMenu(from: CGRect.zero, in: self.view, animated: true)
        }
        previewDocumentMessageId = message.messageId
    }
    
    private func showLoading() {
        loadingView.startAnimating()
        titleStackView.isHidden = true
    }
    
    private func hideLoading() {
        loadingView.stopAnimating()
        titleStackView.isHidden = false
    }

    private func openAction(action: String) {
        guard !action.isEmpty else {
            return
        }
        guard action.hasPrefix("input:"), action.count > 6 else {
            if let url = URL(string: action) {
                open(url: url)
            }
            return
        }

        let inputAction = String(action.suffix(action.count - 6))
        if !inputAction.isEmpty {
            dataSource.sendMessage(type: .SIGNAL_TEXT,
                                   quoteMessageId: nil,
                                   value: inputAction)
        }
    }

    private func open(url: URL) {
        guard !UrlWindow.checkUrl(url: url, checkLastWindow: false) else {
            return
        }
        guard !conversationId.isEmpty else {
            return
        }
        WebViewController.presentInstance(with: .init(conversationId: conversationId, initialUrl: url), asChildOf: self)
    }
    
    private func report(conversationId: String) {
        DispatchQueue.global().async { [weak self] in
            let developID = AccountAPI.shared.accountIdentityNumber == "762532" ? "31911" : "762532"
            var user = UserDAO.shared.getUser(identityNumber: developID)
            if user == nil {
                switch UserAPI.shared.search(keyword: developID) {
                case let .success(userResponse):
                    UserDAO.shared.updateUsers(users: [userResponse])
                    user = UserItem.createUser(from: userResponse)
                case .failure:
                    return
                }
            }
            guard let developUser = user, let url = FileManager.default.exportLog(conversationId: conversationId) else {
                return
            }
            let targetUrl = MixinFile.url(ofChatDirectory: .files, filename: url.lastPathComponent)
            do {
                try FileManager.default.copyItem(at: url, to: targetUrl)
                try FileManager.default.removeItem(at: url)
            } catch {
                return
            }
            guard FileManager.default.fileSize(targetUrl.path) > 0 else {
                return
            }
            
            let developConversationId = ConversationDAO.shared.makeConversationId(userId: AccountAPI.shared.accountUserId, ownerUserId: developUser.userId)
            var message = Message.createMessage(category: MessageCategory.PLAIN_DATA.rawValue, conversationId: developConversationId, userId: AccountAPI.shared.accountUserId)
            message.name = url.lastPathComponent
            message.mediaSize = FileManager.default.fileSize(targetUrl.path)
            message.mediaMimeType = FileManager.default.mimeType(ext: url.pathExtension)
            message.mediaUrl = url.lastPathComponent
            message.mediaStatus = MediaStatus.PENDING.rawValue
            
            self?.dataSource?.queue.async {
                SendMessageService.shared.sendMessage(message: message, ownerUser: developUser, isGroupMessage: false)
                DispatchQueue.main.async {
                    self?.navigationController?.pushViewController(withBackRoot: ConversationViewController.instance(ownerUser: developUser))
                }
            }
        }
    }
    
    private func deleteForMe(viewModel: MessageViewModel) {
        let message = viewModel.message
        if viewModel.message.messageId == AudioManager.shared.playingMessage?.messageId {
            AudioManager.shared.stop()
        }
        dataSource?.queue.async { [weak self] in
            guard let weakSelf = self, let indexPath = weakSelf.dataSource.indexPath(where: { $0.messageId == message.messageId }) else {
                return
            }
            (viewModel as? AttachmentLoadingViewModel)?.cancelAttachmentLoading(isTriggeredByUser: true)
            if MessageDAO.shared.deleteMessage(id: message.messageId) {
                ReceiveMessageService.shared.stopRecallMessage(messageId: message.messageId, category: message.category, conversationId: message.conversationId, mediaUrl: message.mediaUrl)
            }
            DispatchQueue.main.sync {
                _ = weakSelf.dataSource?.removeViewModel(at: indexPath)
                weakSelf.tableView.reloadData()
                weakSelf.tableView.setFloatingHeaderViewsHidden(true, animated: true)
            }
        }
    }
    
    private func deleteForEveryone(viewModel: MessageViewModel) {
        let message = viewModel.message
        if viewModel.message.messageId == AudioManager.shared.playingMessage?.messageId {
            AudioManager.shared.stop()
        }
        (viewModel as? AttachmentLoadingViewModel)?.cancelAttachmentLoading(isTriggeredByUser: true)
        SendMessageService.shared.recallMessage(messageId: message.messageId, category: message.category, mediaUrl: message.mediaUrl, conversationId: message.conversationId, status: message.status, sendToSession: true)
    }

    private func showRecallTips(viewModel: MessageViewModel) {
        let alc = UIAlertController(title: R.string.localizable.chat_delete_tip(), message: "", preferredStyle: .alert)
        alc.addAction(UIAlertAction(title: R.string.localizable.action_learn_more(), style: .default, handler: { (_) in
            CommonUserDefault.shared.isRecallTips = true
            UIApplication.shared.openURL(url: "https://mixinmessenger.zendesk.com/hc/articles/360028209571")
        }))
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_OK, style: .default, handler: { (_) in
            CommonUserDefault.shared.isRecallTips = true
            self.deleteForEveryone(viewModel: viewModel)
        }))
        present(alc, animated: true, completion: nil)
    }
    
    private func reloadWithMessageIdAndBlinkTheCell(_ messageId: String, upwards: Bool) {
        let scroll = upwards ? dataSource.scrollToBottomAndReload : dataSource.scrollToTopAndReload
        scroll(messageId, {
            guard let indexPath = self.dataSource?.indexPath(where: { $0.messageId == messageId }) else {
                return
            }
            if upwards {
                self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: false)
            } else {
                self.tableView.scrollToRow(at: indexPath, at: .top, animated: false)
            }
            UIView.animate(withDuration: 0.3, animations: {
                self.tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
            }, completion: { (_) in
                if let indexPath = self.dataSource.indexPath(where: { $0.messageId == messageId }) {
                    self.blinkCellBackground(at: indexPath)
                }
            })
        })
    }
    
}

// MARK: - Embedded classes
extension ConversationViewController {
    
    struct Position: CustomDebugStringConvertible {
        let messageId: String
        let offset: CGFloat
        
        var debugDescription: String {
            return "{\(messageId), \(offset)}"
        }
    }
    
    class ResizeInputWrapperGestureRecognizer: UIPanGestureRecognizer {
        
        var hasMovedInputWrapperDuringChangedState = false
        var inputWrapperHeightWhenBegan: CGFloat = 0
        
        override func reset() {
            super.reset()
            hasMovedInputWrapperDuringChangedState = false
        }
        
    }
    
}
