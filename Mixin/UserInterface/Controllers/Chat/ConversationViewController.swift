import UIKit
import MobileCoreServices
import AVKit
import Photos

class ConversationViewController: UIViewController, StatusBarStyleSwitchableViewController {
    
    @IBOutlet weak var galleryWrapperView: UIView!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var connectionHintView: ConnectionHintView!
    @IBOutlet weak var tableView: ConversationTableView!
    @IBOutlet weak var announcementButton: UIButton!
    @IBOutlet weak var scrollToBottomWrapperView: UIView!
    @IBOutlet weak var scrollToBottomButton: UIButton!
    @IBOutlet weak var unreadBadgeLabel: UILabel!
    @IBOutlet weak var bottomOutsideWrapperView: UIView!
    @IBOutlet weak var inputWrapperView: UIView!
    @IBOutlet weak var moreButton: UIButton!
    @IBOutlet weak var botButton: UIButton!
    @IBOutlet weak var inputTextView: InputTextView!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var toggleStickerPanelSizeButton: UIButton!
    @IBOutlet weak var stickerKeyboardSwitcherButton: UIButton!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var participantsLabel: UILabel!
    @IBOutlet weak var unblockButton: StateResponsiveButton!
    @IBOutlet weak var deleteConversationButton: StateResponsiveButton!
    @IBOutlet weak var stickerInputContainerView: UIView!
    @IBOutlet weak var moreMenuContainerView: UIView!
    @IBOutlet weak var dismissPanelsButton: UIButton!
    @IBOutlet weak var loadingView: UIActivityIndicatorView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var audioInputContainerView: UIView!
    @IBOutlet weak var quotePreviewView: QuotePreviewView!
    
    @IBOutlet weak var statusBarPlaceholderHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollToBottomWrapperHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputTextViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputTextViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputTextViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputTextViewLeadingShrinkConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputTextViewLeadingExpandedConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputWrapperBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var stickerPanelContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var moreMenuHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var moreMenuTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var audioInputContainerWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var quoteViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var quoteViewHiddenConstraint: NSLayoutConstraint!
    @IBOutlet weak var quoteViewShowConstraint: NSLayoutConstraint!
    
    static var positions = [String: Position]()
    
    var dataSource: ConversationDataSource!
    var conversationId: String {
        return dataSource.conversationId
    }
    var statusBarStyle = UIStatusBarStyle.default {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }
    var statusBarHidden = false {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }
    var homeIndicatorAutoHidden = false {
        didSet {
            if #available(iOS 11.0, *) {
                setNeedsUpdateOfHomeIndicatorAutoHidden()
            }
        }
    }
    
    private let maxInputRow = 6
    private let showScrollToBottomButtonThreshold: CGFloat = 150
    private let loadMoreMessageThreshold = 20
    private let animationDuration: TimeInterval = 0.25
    private let moreMenuSegueId = "MoreMenuSegueId"
    private let audioInputSegueId = "AudioInputSegueId"
    
    private var ownerUser: UserItem?
    private var ownerUserApp: App?
    private var participants = [Participant]()
    private var role = ""
    private var asset: AssetItem?
    private var quoteMessageId: String?
    private var quotingMessageId: String?
    private var didInitData = false
    private var isShowingMenu = false
    private var isShowingStickerPanel = false
    private var isAppearanceAnimating = true
    private var isStickerPanelMax = false
    private var inputWrapperShouldFollowKeyboardPosition = true
    private var tableViewContentOffsetShouldFollowInputWrapperPosition = true
    private var didManuallyStoppedTableViewDecelerating = false
    private var isShowingQuotePreviewView: Bool {
        return quoteMessageId != nil
    }
    
    private var keyboardManager = ConversationKeyboardManager()
    private var tapRecognizer: UITapGestureRecognizer!
    private var reportRecognizer: UILongPressGestureRecognizer!
    private var moreMenuViewController: ConversationMoreMenuViewController?
    private var audioInputViewController: AudioInputViewController?
    private var previewDocumentController: UIDocumentInteractionController?
    
    private(set) lazy var imagePickerController = ImagePickerController(initialCameraPosition: .rear, cropImageAfterPicked: false, parent: self)
    private lazy var userWindow = UserWindow.instance()
    private lazy var groupWindow = GroupWindow.instance()
    private lazy var lastInputWrapperBottomConstant = bottomSafeAreaInset
    
    private lazy var stickerInputViewController: StickerInputViewController = {
        let controller = StickerInputViewController.instance()
        addChildViewController(controller)
        stickerInputContainerView.addSubview(controller.view)
        controller.view.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
        controller.didMove(toParentViewController: self)
        stickerInputContainerView.layoutIfNeeded()
        return controller
    }()
    private lazy var galleryViewController: GalleryViewController = {
        let controller = GalleryViewController.instance(conversationId: conversationId)
        controller.delegate = self
        addChildViewController(controller)
        galleryWrapperView.addSubview(controller.view)
        controller.view.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
        controller.didMove(toParentViewController: self)
        return controller
    }()
    private lazy var strangerTipsView: StrangerTipsView = {
        let view = StrangerTipsView()
        view.frame.size.height = StrangerTipsView.height
        view.blockButton.addTarget(self, action: #selector(blockAction(_:)), for: .touchUpInside)
        view.addContactButton.addTarget(self, action: #selector(addContactAction(_:)), for: .touchUpInside)
        return view
    }()

    private var bottomSafeAreaInset: CGFloat {
        if #available(iOS 11.0, *) {
            return view.safeAreaInsets.bottom
        } else {
            return 0
        }
    }

    private var stickerPanelFullsizedHeight: CGFloat {
        if #available(iOS 11.0, *) {
            return view.frame.height - 56 - max(view.safeAreaInsets.top, 20) - view.safeAreaInsets.bottom - 55
        } else {
            return view.frame.height - 56 - 20 - 55
        }
    }
    
    private var isShowingMoreMenu: Bool {
        return moreMenuTopConstraint.constant > 0.1
    }
    
    private var unreadBadgeValue: Int = 0 {
        didSet {
            guard unreadBadgeValue != oldValue else {
                return
            }
            unreadBadgeLabel.isHidden = unreadBadgeValue <= 0
            unreadBadgeLabel.text = unreadBadgeValue <= 99 ? String(unreadBadgeValue) : "99+"
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return statusBarHidden
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return statusBarStyle
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

        audioInputContainerWidthConstraint.constant = 55
        quotePreviewView.dismissAction = { [weak self] in
            self?.setQuoteViewHidden(true)
        }
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        tapRecognizer.delegate = self
        tableView.addGestureRecognizer(tapRecognizer)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.actionDelegate = self
        tableView.viewController = self
        keyboardManager.delegate = self
        inputTextView.delegate = self
        inputTextView.layer.cornerRadius = inputTextViewHeightConstraint.constant / 2
        inputTextView.inputAccessoryView = keyboardManager.inputAccessoryView
        connectionHintView.delegate = self
        announcementButton.isHidden = !CommonUserDefault.shared.hasUnreadAnnouncement(conversationId: conversationId)
        dataSource.ownerUser = ownerUser
        dataSource.tableView = tableView
        updateMoreMenuFixedJobs()
        updateMoreMenuApps()
        updateStrangerTipsView()
        updateBottomView()
        inputWrapperView.isHidden = false
        updateNavigationBar()
        reloadParticipants()
        NotificationCenter.default.addObserver(self, selector: #selector(conversationDidChange(_:)), name: .ConversationDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(userDidChange(_:)), name: .UserDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuControllerDidShowMenu(_:)), name: .UIMenuControllerDidShowMenu, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuControllerDidHideMenu(_:)), name: .UIMenuControllerDidHideMenu, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(participantDidChange(_:)), name: .ParticipantDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(assetsDidChange(_:)), name: .AssetsDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didAddedMessagesOutsideVisibleBounds(_:)), name: Notification.Name.ConversationDataSource.DidAddedMessagesOutsideVisibleBounds, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillTerminate(_:)), name: .UIApplicationWillTerminate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeStatusBarFrame(_:)), name: .UIApplicationDidChangeStatusBarFrame, object: nil)
    }

    @objc func showReportMenuAction() {
        guard !self.conversationId.isEmpty else {
            return
        }

        let conversationId = self.conversationId
        let alc = UIAlertController(title: Localized.REPORT_TITLE, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.REPORT_BUTTON, style: .default, handler: { [weak self](_) in
            self?.reportAction(conversationId: conversationId)
        }))
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        self.present(alc, animated: true, completion: nil)
    }

    private func reportAction(conversationId: String) {
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
            var message = Message.createMessage(category: MessageCategory.SIGNAL_DATA.rawValue, conversationId: developConversationId, userId: AccountAPI.shared.accountUserId)
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

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == moreMenuSegueId, let destination = segue.destination as? ConversationMoreMenuViewController {
            moreMenuViewController = destination
        } else if segue.identifier == audioInputSegueId, let destination = segue.destination as? AudioInputViewController {
            audioInputViewController = destination
        }
    }
    
    @available(iOS 11.0, *)
    override func prefersHomeIndicatorAutoHidden() -> Bool {
        return homeIndicatorAutoHidden
    }
    
    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        if inputWrapperBottomConstraint.constant == 0 {
            inputWrapperBottomConstraint.constant = bottomSafeAreaInset
            updateTableViewContentInset()
        }
    }
    
    override func preferredContentSizeDidChange(forChildContentContainer container: UIContentContainer) {
        super.preferredContentSizeDidChange(forChildContentContainer: container)
        if (container as? UIViewController) == audioInputViewController {
            let isExpanding = container.preferredContentSize.width > audioInputContainerWidthConstraint.constant
            audioInputContainerWidthConstraint.constant = container.preferredContentSize.width
            if isExpanding {
                UIView.animate(withDuration: animationDuration, animations: {
                    self.view.layoutIfNeeded()
                })
            } else {
                view.layoutIfNeeded()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isAppearanceAnimating = true
        if !didInitData {
            didInitData = true
            view.layoutIfNeeded()
            if let draft = CommonUserDefault.shared.getConversationDraft(conversationId) {
                inputTextView.text = draft
                UIView.performWithoutAnimation {
                    textViewDidChange(inputTextView)
                }
                inputTextView.contentOffset.y = inputTextView.contentSize.height - inputTextView.frame.height
            }
            updateTableViewContentInset()
            dataSource.initData {
                self.updateAccessoryButtons(animated: false)
                self.stickerInputViewController.reload()
                DispatchQueue.global().async { [weak self] in
                    self?.asset = AssetDAO.shared.getAvailableAssetId(assetId: WalletUserDefault.shared.defalutTransferAssetId)
                }
                self.hideLoading()
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isAppearanceAnimating = false
        if inputTextView.isFirstResponder {
            // Workaround for iOS 11 keyboard misplacing
            keyboardManager.inputAccessoryViewHeight = inputWrapperView.frame.height
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dismissMenu(animated: true)
        isAppearanceAnimating = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        saveDraft()
        MXNAudioPlayer.shared().stop(withAudioSessionDeactivated: true)
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
                    ConversationViewController.positions[conversationId] = Position(messageId: message.messageId, offset: offset)
                    break
                }
            }
        }
        if parent == nil {
            dataSource?.cancelMessageProcessing()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Actions
    @IBAction func profileAction(_ sender: Any) {
        if let dataSource = dataSource, dataSource.category == .group {
            groupWindow.bounds.size.width = view.bounds.width
            groupWindow.updateGroup(conversation: dataSource.conversation).presentView()
        } else if let user = ownerUser {
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
            dataSource?.scrollToBottomAndReload(initialMessageId: quotingMessageId, completion: {
                if let indexPath = self.dataSource?.indexPath(where: { $0.messageId == quotingMessageId }) {
                    self.blinkCellBackground(at: indexPath)
                }
            })
        } else {
            dataSource?.scrollToFirstUnreadMessageOrBottom()
        }
    }
    
    @IBAction func moreAction(_ sender: Any) {
        var delay: TimeInterval = 0
        if isShowingStickerPanel {
            delay = animationDuration
            toggleStickerPanel(delay: 0)
        }
        makeInputTextViewResignFirstResponderIfItIs()
        DispatchQueue.main.async {
            self.toggleMoreMenu(delay: delay)
        }
    }
    
    @IBAction func stickerKeyboardSwitchAction(_ sender: Any) {
        var delay: TimeInterval = 0
        if isShowingMoreMenu {
            toggleMoreMenu(delay: 0)
            delay = animationDuration
        }
        bottomOutsideWrapperView.backgroundColor = .white
        if isShowingStickerPanel {
            inputTextView.becomeFirstResponder()
        } else {
            inputWrapperShouldFollowKeyboardPosition = false
            inputTextView.resignFirstResponder()
            inputWrapperShouldFollowKeyboardPosition = true
            toggleStickerPanel(delay: delay)
        }
    }

    @IBAction func botAction(_ sender: Any) {
        guard let user = ownerUser, user.isBot, let app = self.ownerUserApp else {
            return
        }
        guard let url = URL(string: app.homeUri), !conversationId.isEmpty else {
            return
        }

        if isShowingMoreMenu {
            toggleMoreMenu(delay: 0)
        }
        if isShowingStickerPanel {
            toggleStickerPanel(delay: 0)
        }
        presentWebWindow(withURL: url)
    }
    
    @IBAction func toggleStickerPanelSizeAction(_ sender: Any) {
        let dismissButtonAlpha: CGFloat
        if isStickerPanelMax {
            stickerPanelContainerHeightConstraint.constant = ConversationKeyboardManager.lastKeyboardHeight
            dismissButtonAlpha = 0
        } else {
            stickerPanelContainerHeightConstraint.constant = stickerPanelFullsizedHeight
            dismissButtonAlpha = 0.3
        }
        inputWrapperBottomConstraint.constant = stickerPanelContainerHeightConstraint.constant
        isStickerPanelMax = !isStickerPanelMax
        toggleStickerPanelSizeButton.animationSwapImage(newImage: isStickerPanelMax ? #imageLiteral(resourceName: "ic_chat_panel_min") : #imageLiteral(resourceName: "ic_chat_panel_max"))
        UIView.animate(withDuration: animationDuration, animations: {
            self.dismissPanelsButton.alpha = dismissButtonAlpha
            self.view.layoutIfNeeded()
        })
    }
    
    @IBAction func sendTextMessageAction(_ sender: Any) {
        guard !trimmedMessageDraft.isEmpty else {
            return
        }
        dataSource?.sendMessage(type: .SIGNAL_TEXT, quoteMessageId: quoteMessageId , value: trimmedMessageDraft)
        inputTextView.text = ""
        textViewDidChange(inputTextView)
        setQuoteViewHidden(true)
    }
    
    @IBAction func dismissPanelsAction(_ sender: Any) {
        if isShowingStickerPanel && isStickerPanelMax {
            toggleStickerPanel(delay: 0)
        } else {
            toggleMoreMenu(delay: 0)
        }
    }

    @IBAction func deleteConversationAction(_ sender: Any) {
        guard !self.conversationId.isEmpty else {
            return
        }
        deleteConversationButton.isBusy = true
        let conversationId = self.conversationId
        DispatchQueue.global().async { [weak self] in
            ConversationDAO.shared.makeQuitConversation(conversationId: conversationId)
            NotificationCenter.default.postOnMain(name: .ConversationDidChange)
            DispatchQueue.main.async {
                self?.navigationController?.backToHome()
            }
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
            case .failure:
               break
            }
        }
    }
    
    @objc func unblockAction(_ sender: Any) {
        guard let user = ownerUser else {
            return
        }
        unblockButton.isBusy = true
        UserAPI.shared.unblockUser(userId: user.userId) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.unblockButton.isBusy = false
            switch result {
            case .success(let userResponse):
                weakSelf.updateOwnerUser(withUserResponse: userResponse, updateDatabase: true)
            case .failure:
                break
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
            case .failure:
                break
            }
        }
    }
    
    @objc func tapAction(_ recognizer: UIGestureRecognizer) {
        if let audioInputViewController = audioInputViewController, audioInputViewController.isShowingLongPressHint {
            audioInputViewController.animateHideLongPressHint()
            return
        }
        if isShowingMenu {
            dismissMenu(animated: true)
            return
        }
        if isShowingStickerPanel {
            toggleStickerPanel(delay: 0)
            return
        }
        if let indexPath = tableView.indexPathForRow(at: recognizer.location(in: tableView)), let cell = tableView.cellForRow(at: indexPath) as? MessageCell, cell.contentFrame.contains(recognizer.location(in: cell)), let viewModel = dataSource?.viewModel(for: indexPath) {
            let message = viewModel.message
            if message.category.hasSuffix("_TEXT"), let cell = cell as? QuoteTextMessageCell, cell.quoteBackgroundImageView.frame.contains(recognizer.location(in: cell)), let quoteMessageId = viewModel.message.quoteMessageId {
                if let indexPath = dataSource?.indexPath(where: { $0.messageId == quoteMessageId }) {
                    quotingMessageId = message.messageId
                    tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
                    blinkCellBackground(at: indexPath)
                } else if MessageDAO.shared.hasMessage(id: quoteMessageId) {
                    quotingMessageId = message.messageId
                    dataSource?.scrollToTopAndReload(initialMessageId: quoteMessageId, completion: {
                        if let indexPath = self.dataSource?.indexPath(where: { $0.messageId == quoteMessageId }) {
                            self.blinkCellBackground(at: indexPath)
                        }
                    })
                }
            } else if message.category.hasSuffix("_AUDIO"), message.mediaStatus == MediaStatus.DONE.rawValue, let cell = cell as? AudioMessageCell {
                let cellIsPlaying = cell.isPlaying
                MXNAudioPlayer.shared().stop(withAudioSessionDeactivated: cellIsPlaying)
                if !cellIsPlaying {
                    cell.isPlaying = true
                    if let mediaUrl = viewModel.message.mediaUrl {
                        let path = MixinFile.url(ofChatDirectory: .audios, filename: mediaUrl).path
                        MXNAudioPlayer.shared().playFile(atPath: path) { [weak cell] (success, error) in
                            if let error = error as? MXNAudioPlayerError, error == .cancelled {
                                DispatchQueue.main.async {
                                    cell?.isPlaying = false
                                }
                            } else if let error = error {
                                UIApplication.trackError("ConversationViewController", action: "Play audio", userInfo: ["error": error])
                            }
                        }
                    }
                }
            } else if message.category.hasSuffix("_IMAGE") || message.category.hasSuffix("_VIDEO"), message.mediaStatus == MediaStatus.DONE.rawValue, let item = GalleryItem(message: message) {
                tableViewContentOffsetShouldFollowInputWrapperPosition = false
                makeInputTextViewResignFirstResponderIfItIs()
                MXNAudioPlayer.shared().stop(withAudioSessionDeactivated: true)
                tableViewContentOffsetShouldFollowInputWrapperPosition = true
                view.bringSubview(toFront: galleryWrapperView)
                if let viewModel = viewModel as? PhotoRepresentableMessageViewModel, case let .relativeOffset(offset) = viewModel.layoutPosition {
                    galleryViewController.show(item: item, offset: offset)
                } else {
                    galleryViewController.show(item: item, offset: 0)
                }
                homeIndicatorAutoHidden = true
            } else if message.category.hasSuffix("_DATA"), let viewModel = viewModel as? DataMessageViewModel, let cell = cell as? DataMessageCell {
                if viewModel.mediaStatus == MediaStatus.DONE.rawValue {
                    makeInputTextViewResignFirstResponderIfItIs()
                    openDocumentAction(message: message)
                } else {
                    attachmentLoadingCellDidSelectNetworkOperation(cell)
                }
            } else if message.category.hasSuffix("_CONTACT"), let shareUserId = message.sharedUserId {
                makeInputTextViewResignFirstResponderIfItIs()
                if shareUserId == AccountAPI.shared.accountUserId {
                    navigationController?.pushViewController(withBackRoot: MyProfileViewController.instance())
                } else if let user = UserDAO.shared.getUser(userId: shareUserId) {
                    UserWindow.instance().updateUser(user: user).presentView()
                }
            } else if message.category == MessageCategory.EXT_ENCRYPTION.rawValue {
                makeInputTextViewResignFirstResponderIfItIs()
                open(url: .aboutEncryption)
            } else if message.category == MessageCategory.SYSTEM_ACCOUNT_SNAPSHOT.rawValue {
                makeInputTextViewResignFirstResponderIfItIs()
                DispatchQueue.global().async { [weak self] in
                    guard let assetId = message.snapshotAssetId, let snapshotId = message.snapshotId, let asset = AssetDAO.shared.getAsset(assetId: assetId), let snapshot = SnapshotDAO.shared.getSnapshot(snapshotId: snapshotId) else {
                        return
                    }
                    DispatchQueue.main.async {
                        self?.navigationController?.pushViewController(TransactionViewController.instance(asset: asset, snapshot: snapshot), animated: true)
                    }
                }
            } else if message.category == MessageCategory.APP_CARD.rawValue, let action = message.appCard?.action {
                makeInputTextViewResignFirstResponderIfItIs()
                open(url: action)
            } else {
                makeInputTextViewResignFirstResponderIfItIs()
            }
        } else {
            makeInputTextViewResignFirstResponderIfItIs()
        }
    }
    
    // MARK: - Callbacks
    @objc func conversationDidChange(_ sender: Notification) {
        guard let change = sender.object as? ConversationChange, change.conversationId == conversationId else {
            return
        }
        switch change.action {
        case let .updateGroupIcon(iconUrl):
            avatarImageView?.setGroupImage(with: iconUrl, conversationId: conversationId)
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
            updateBottomView()
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
        inputTextView.overrideNext = nil
    }
    
    @objc func participantDidChange(_ notification: Notification) {
        guard let conversationId = notification.object as? String, conversationId == self.conversationId else {
            return
        }
        updateMoreMenuApps()
        reloadParticipants()
    }
    
    @objc func assetsDidChange(_ notification: Notification) {
        DispatchQueue.global().async { [weak self] in
            self?.asset = AssetDAO.shared.getAvailableAssetId(assetId: WalletUserDefault.shared.defalutTransferAssetId)
        }
    }
    
    @objc func didAddedMessagesOutsideVisibleBounds(_ notification: Notification) {
        guard let count = notification.object as? Int else {
            return
        }
        unreadBadgeValue += count
    }
    
    @objc func didChangeStatusBarFrame(_ notification: Notification) {
        updateTableViewContentInset()
    }
    
    @objc func applicationWillTerminate(_ notification: Notification) {
        saveDraft()
    }
    
    // MARK: - Interface
    func toggleMoreMenu(delay: TimeInterval) {
        let dismissButtonAlpha: CGFloat
        let shouldHideContainer = isShowingMoreMenu
        if isShowingMoreMenu {
            moreMenuTopConstraint.constant = 0
            dismissButtonAlpha = 0
        } else {
            moreMenuContainerView.isHidden = false
            moreMenuTopConstraint.constant = moreMenuViewController?.contentHeight ?? moreMenuHeightConstraint.constant
            dismissButtonAlpha = 0.3
        }
        UIView.animate(withDuration: animationDuration, delay: delay, options: [], animations: {
            UIView.setAnimationCurve(.overdamped)
            self.dismissPanelsButton.alpha = dismissButtonAlpha
            self.view.layoutIfNeeded()
        }) { (success) in
            if shouldHideContainer {
                self.moreMenuContainerView.isHidden = true
            }
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
            viewController = TransferViewController.instance(user: user, conversationId: conversationId, asset: asset)
        } else {
            viewController = WalletPasswordViewController.instance(fromChat:  user, conversationId: conversationId, asset: asset)
        }
        navigationController?.pushViewController(viewController, animated: true)
    }

    func contactAction() {
        navigationController?.pushViewController(ConversationShareContactViewController.instance(ownerUser: ownerUser, conversationId: conversationId), animated: true)
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

    func reduceStickerPanelHeightIfMaximized() {
        guard isStickerPanelMax else {
            return
        }
        toggleStickerPanelSizeAction(self)
    }
    
    func setInputWrapperHidden(_ hidden: Bool) {
        UIView.animate(withDuration: animationDuration) {
            self.inputWrapperView.alpha = hidden ? 0 : 1
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
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if isShowingMenu {
            return true
        }
        if let view = touch.view as? TextMessageLabel {
            return !view.canResponseTouch(at: touch.location(in: view))
        }
        return true
    }
    
}

// MARK: - UITextViewDelegate
extension ConversationViewController: UITextViewDelegate {
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        return !(audioInputViewController?.isRecording ?? false)
    }
    
    func textViewDidChange(_ textView: UITextView) {
        guard let lineHeight = textView.font?.lineHeight else {
            return
        }
        let maxHeight = ceil(lineHeight * CGFloat(maxInputRow) + textView.textContainerInset.top + textView.textContainerInset.bottom)
        let contentSize = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: UILayoutFittingExpandedSize.height))
        inputTextView.isScrollEnabled = contentSize.height > maxHeight
        if !trimmedMessageDraft.isEmpty || isShowingQuotePreviewView {
            sendButton.isHidden = false
            audioInputContainerView.isHidden = true
            stickerKeyboardSwitcherButton.isHidden = true
        } else {
            sendButton.isHidden = true
            audioInputContainerView.isHidden = false
            stickerKeyboardSwitcherButton.isHidden = false
        }
        let newHeight = min(contentSize.height, maxHeight)
        let heightDifference = newHeight - inputTextViewHeightConstraint.constant
        if abs(heightDifference) > 0.1 {
            inputTextViewHeightConstraint.constant = newHeight
            let newContentOffset = tableView.contentOffset.y + heightDifference
            UIView.animate(withDuration: animationDuration, animations: {
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
                self.updateTableViewContentInset()
                self.tableView.setContentOffsetYSafely(newContentOffset)
            }, completion: { (_) in
                self.keyboardManager.inputAccessoryViewHeight = self.inputWrapperView.frame.height
            })
        }
    }
    
}

// MARK: - ConnectionHintViewDelegate
extension ConversationViewController: ConnectionHintViewDelegate {
    
    func animateAlongsideConnectionHintView(_ view: ConnectionHintView, changingHeightWithDifference heightDifference: CGFloat) {
        updateTableViewContentInset()
        tableView.contentInset.top += view.connectionHintViewHeightConstraint.constant
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
        return !inputTextView.isFirstResponder
    }
    
    func conversationTableViewLongPressWillBegan(_ tableView: ConversationTableView) {
        inputTextView.overrideNext = tableView
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
            (viewModel as? AttachmentLoadingViewModel)?.cancelAttachmentLoading(markMediaStatusCancelled: false)
            dataSource?.queue.async { [weak self] in
                MessageDAO.shared.deleteMessage(id: message.messageId)
                DispatchQueue.main.sync {
                    guard let weakSelf = self else {
                        return
                    }
                    if let (didRemoveRow, didRemoveSection) = weakSelf.dataSource?.removeViewModel(at: indexPath) {
                        if didRemoveSection {
                            weakSelf.tableView.deleteSections(IndexSet(integer: indexPath.section), with: .fade)
                        } else if didRemoveRow {
                            weakSelf.tableView.deleteRows(at: [indexPath], with: .fade)
                        }
                    }
                    weakSelf.tableView.setFloatingHeaderViewsHidden(true, animated: true)
                }
            }
        case .forward:
            audioInputViewController?.cancelIfRecording()
            navigationController?.pushViewController(ForwardViewController.instance(message: message, ownerUser: ownerUser), animated: true)
        case .reply:
            audioInputViewController?.cancelIfRecording()
            quoteMessageId = message.messageId
            quotePreviewView.render(message: message, contentImageThumbnail: viewModel.thumbnail)
            setQuoteViewHidden(false)
            inputTextView?.becomeFirstResponder()
            let newTableViewHeight = tableView.frame.height - ConversationKeyboardManager.lastKeyboardHeight - inputWrapperView.frame.height
            let offsetY = tableView.rectForRow(at: indexPath).maxY - newTableViewHeight + quotePreviewView.frame.height
            if offsetY > 0 {
                UIView.animate(withDuration: 0.5, animations: {
                    UIView.setAnimationCurve(.overdamped)
                    tableView.contentOffset.y = offsetY
                })
            }
        case .add:
            if message.category.hasSuffix("_STICKER"), let stickerId = message.stickerId {
                StickerAPI.shared.addSticker(stickerId: stickerId, completion: { (result) in
                    switch result {
                    case let .success(sticker):
                        DispatchQueue.global().async {
                            StickerDAO.shared.insertOrUpdateFavoriteSticker(sticker: sticker)
                            NotificationCenter.default.postOnMain(name: .ToastMessageDidAppear, object: Localized.TOAST_ADDED)
                        }
                    case .failure:
                        break
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
            self.tableView.setFloatingHeaderViewsHidden(true, animated: true)
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
            viewModel.beginAttachmentLoading()
        }
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let viewModel = dataSource?.viewModel(for: indexPath) else {
            return
        }
        if let viewModel = viewModel as? AttachmentLoadingViewModel, viewModel.automaticallyLoadsAttachment {
            viewModel.cancelAttachmentLoading(markMediaStatusCancelled: false)
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
            UIApplication.trackError("ConversationViewController", action: "Invalid row height", userInfo: ["viewModel": viewModel.debugDescription])
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
        let appButton = appButtons[index]
        let action = appButton.action.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? appButton.action
        if let url = URL(string: action) {
            open(url: url)
        }
    }
    
}

// MARK: - AttachmentLoadingMessageCellDelegate
extension ConversationViewController: AttachmentLoadingMessageCellDelegate {
    
    func attachmentLoadingCellDidSelectNetworkOperation(_ cell: MessageCell & AttachmentLoadingMessageCell) {
        guard let indexPath = tableView.indexPath(for: cell), let viewModel = dataSource?.viewModel(for: indexPath) as? MessageViewModel & AttachmentLoadingViewModel, let mediaStatus = viewModel.mediaStatus else {
            return
        }
        switch mediaStatus {
        case MediaStatus.CANCELED.rawValue:
            viewModel.beginAttachmentLoading()
        case MediaStatus.PENDING.rawValue:
            viewModel.cancelAttachmentLoading(markMediaStatusCancelled: true)
        default:
            break
        }
    }
    
}

// MARK: - CoreTextLabelDelegate
extension ConversationViewController: CoreTextLabelDelegate {
    
    func coreTextLabel(_ label: CoreTextLabel, didSelectURL url: URL) {
        open(url: url)
    }
    
    func coreTextLabel(_ label: CoreTextLabel, didLongPressOnURL url: URL) {
        let alert = UIAlertController(title: url.absoluteString, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: Localized.CHAT_MESSAGE_OPEN_URL, style: .default, handler: { [weak self](_) in
            self?.open(url: url)
        }))
        alert.addAction(UIAlertAction(title: Localized.CHAT_MESSAGE_MENU_COPY, style: .default, handler: { (_) in
            UIPasteboard.general.string = url.absoluteString
            NotificationCenter.default.postOnMain(name: .ToastMessageDidAppear, object: Localized.TOAST_COPIED)
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
    
    @available(iOS 11.0, *)
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
    }
    
}

// MARK: - GalleryViewControllerDelegate
extension ConversationViewController: GalleryViewControllerDelegate {
    
    func galleryViewController(_ viewController: GalleryViewController, showContextForItemOfMessageId id: String) -> GalleryViewController.ShowContext? {
        guard let indexPath = dataSource?.indexPath(where: { $0.messageId == id }), let viewModel = dataSource.viewModel(for: indexPath) as? PhotoRepresentableMessageViewModel, let cell = tableView.cellForRow(at: indexPath) as? PhotoRepresentableMessageCell else {
            return nil
        }
        return GalleryViewController.ShowContext(sourceFrame: frameOfPhotoRepresentableCell(cell),
                                                 placeholder: cell.contentImageView.image,
                                                 viewModel: viewModel,
                                                 statusSnapshot: cell.statusSnapshot())
    }
    
    func galleryViewController(_ viewController: GalleryViewController, dismissContextForItemOfMessageId id: String) -> GalleryViewController.DismissContext? {
        guard let indexPath = dataSource?.indexPath(where: { $0.messageId == id }), let viewModel = dataSource.viewModel(for: indexPath) as? PhotoRepresentableMessageViewModel else {
            return nil
        }
        var frame: CGRect?
        var snapshot: UIImage?
        if let cell = tableView.cellForRow(at: indexPath) as? PhotoRepresentableMessageCell {
            frame = frameOfPhotoRepresentableCell(cell)
            snapshot = cell.statusSnapshot()
        }
        return GalleryViewController.DismissContext(sourceFrame: frame, viewModel: viewModel, statusSnapshot: snapshot)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, willShowForItemOfMessageId id: String?) {
        setCell(ofMessageId: id, contentViewHidden: true)
        if UIApplication.shared.statusBarFrame.height == StatusBarHeight.inCall {
            UIView.performWithoutAnimation {
                self.statusBarPlaceholderHeightConstraint.constant = StatusBarHeight.inCall
                self.statusBarHidden = true
            }
        } else {
            self.statusBarHidden = true
        }
    }
    
    func galleryViewController(_ viewController: GalleryViewController, didShowForItemOfMessageId id: String?) {
        setCell(ofMessageId: id, contentViewHidden: false)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, willDismissArticleForItemOfMessageId id: String?, atRelativeOffset offset: CGFloat) {
        guard let id = id, let indexPath = dataSource?.indexPath(where: { $0.messageId == id }), let cell = tableView.cellForRow(at: indexPath) as? PhotoRepresentableMessageCell else {
            return
        }
        (dataSource.viewModel(for: indexPath) as? PhotoRepresentableMessageViewModel)?.layoutPosition = .relativeOffset(offset)
        cell.contentImageView.position = .relativeOffset(offset)
        cell.contentImageView.layoutIfNeeded()
    }
    
    func galleryViewController(_ viewController: GalleryViewController, willDismissForItemOfMessageId id: String?) {
        setCell(ofMessageId: id, contentViewHidden: true)
        if statusBarPlaceholderHeightConstraint.constant != StatusBarHeight.inCall {
            statusBarHidden = false
        }
    }
    
    func galleryViewController(_ viewController: GalleryViewController, didDismissForItemOfMessageId id: String?) {
        setCell(ofMessageId: id, contentViewHidden: false)
        if statusBarPlaceholderHeightConstraint.constant == StatusBarHeight.inCall {
            statusBarPlaceholderHeightConstraint.constant = StatusBarHeight.normal
            statusBarHidden = false
        }
        view.sendSubview(toBack: galleryWrapperView)
        homeIndicatorAutoHidden = false
    }
    
    func galleryViewController(_ viewController: GalleryViewController, willBeginInteractivelyDismissingForItemOfMessageId id: String?) {
        setCell(ofMessageId: id, contentViewHidden: true)
    }
    
    func galleryViewController(_ viewController: GalleryViewController, didCancelInteractivelyDismissingForItemOfMessageId id: String?) {
        setCell(ofMessageId: id, contentViewHidden: false)
    }

}

// MARK: - PhotoAssetPickerDelegate
extension ConversationViewController: PhotoAssetPickerDelegate {

    func pickerController(_ picker: PickerViewController, contentOffset: CGPoint, didFinishPickingMediaWithAsset asset: PHAsset) {
        navigationController?.pushViewController(AssetSendViewController.instance(asset: asset, dataSource: dataSource), animated: true)
    }
    
}

// MARK: - ConversationKeyboardManagerDelegate
extension ConversationViewController: ConversationKeyboardManagerDelegate {

    func conversationKeyboardManagerScrollViewForInteractiveKeyboardDismissing(_ manager: ConversationKeyboardManager) -> UIScrollView {
        return tableView
    }
    
    func conversationKeyboardManager(_ manager: ConversationKeyboardManager, keyboardWillChangeFrameTo newFrame: CGRect, intent: ConversationKeyboardManager.KeyboardIntent) {
        guard !isAppearanceAnimating && inputWrapperShouldFollowKeyboardPosition else {
            return
        }
        let shouldChangeTableViewContentOffset = intent != .interactivelyChangeFrame
            && tableViewContentOffsetShouldFollowInputWrapperPosition
        let windowHeight = AppDelegate.current.window!.bounds.height
        inputWrapperBottomConstraint.constant = max(windowHeight - newFrame.origin.y - manager.inputAccessoryViewHeight,
                                                    bottomSafeAreaInset)
        let inputWrapperDisplacement = lastInputWrapperBottomConstant - inputWrapperBottomConstraint.constant
        if intent == .show {
            if isShowingStickerPanel {
                UIView.performWithoutAnimation {
                    bottomOutsideWrapperView.backgroundColor = .white
                }
                isShowingStickerPanel = false
                toggleStickerPanelSizeButton.isHidden = true
                stickerKeyboardSwitcherButton.setImage(#imageLiteral(resourceName: "ic_chat_sticker"), for: .normal)
                stickerInputContainerView.alpha = 0
            }
            if inputTextView.hasText || isShowingQuotePreviewView {
                sendButton.isHidden = false
            } else {
                audioInputContainerView.isHidden = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                if manager.isShowingKeyboard {
                    self.bottomOutsideWrapperView.backgroundColor = .clear
                }
            }
        } else if intent == .hide {
            UIView.performWithoutAnimation {
                bottomOutsideWrapperView.backgroundColor = .white
            }
        }
        if isShowingMoreMenu {
            toggleMoreMenu(delay: 0)
        }
        lastInputWrapperBottomConstant = inputWrapperBottomConstraint.constant
        view.layoutIfNeeded()
        let contentOffsetY = tableView.contentOffset.y
        updateTableViewContentInset()
        if !isShowingQuotePreviewView && shouldChangeTableViewContentOffset {
            tableView.setContentOffsetYSafely(contentOffsetY - inputWrapperDisplacement)
        }
        if intent == .show {
            manager.inputAccessoryViewHeight = inputWrapperView.frame.height
        } else if intent == .hide {
            manager.inputAccessoryViewHeight = 0
        }
        DispatchQueue.main.async {
            self.tableView.setFloatingHeaderViewsHidden(true, animated: true)
        }
    }

}

// MARK: - UI Related Helpers
extension ConversationViewController {
    
    private func updateNavigationBar() {
        if let dataSource = dataSource, dataSource.category == .group {
            let conversation = dataSource.conversation
            titleLabel.text = conversation.name
            avatarImageView.setGroupImage(with: conversation.iconUrl, conversationId: conversation.conversationId)
        } else {
            guard let user = ownerUser else {
                return
            }
            participantsLabel.text = user.identityNumber
            titleLabel.text = user.fullName
            avatarImageView.setImage(with: user)
        }
    }
    
    private func updateOwnerUser(withUserResponse userResponse: UserResponse, updateDatabase: Bool) {
        if updateDatabase {
            UserDAO.shared.updateUsers(users: [userResponse], sendNotificationAfterFinished: false)
        }
        ownerUser = UserItem.createUser(from: userResponse)
        updateNavigationBar()
        updateBottomView()
        updateStrangerTipsView()
    }
    
    private func updateBottomView() {
        guard let user = ownerUser else {
            return
        }
        let isBlocked = user.relationship == Relationship.BLOCKING.rawValue
        unblockButton.isHidden = !isBlocked
        audioInputContainerView.isHidden = isBlocked || isShowingStickerPanel
        botButton.isHidden = !user.isBot
    }
    
    private func updateMoreMenuFixedJobs() {
        if dataSource?.category == .contact, let ownerUser = ownerUser, !ownerUser.isBot {
            moreMenuViewController?.fixedJobs = [.transfer, .camera, .photo, .file, .contact]
        } else if let app = ownerUserApp, app.creatorId == AccountAPI.shared.accountUserId {
            moreMenuViewController?.fixedJobs = [.transfer, .camera, .photo, .file, .contact]
        } else {
            moreMenuViewController?.fixedJobs = [.camera, .photo, .file, .contact]
        }
    }
    
    private func updateMoreMenuApps() {
        if Thread.isMainThread {
            DispatchQueue.global().async { [weak self] in
                self?.updateMoreMenuApps()
            }
        } else {
            if dataSource?.category == .group {
                moreMenuViewController?.apps = AppDAO.shared.getConversationBots(conversationId: conversationId)
            } else if let ownerId = ownerUser?.userId, let app = AppDAO.shared.getApp(ofUserId: ownerId) {
                self.ownerUserApp = app
                DispatchQueue.main.async(execute: updateMoreMenuFixedJobs)
            }
        }
    }
    
    private func updateAccessoryButtons(animated: Bool) {
        let position = tableView.contentSize.height - tableView.contentOffset.y - tableView.bounds.height
        if scrollToBottomWrapperView.alpha < 0.1 && position > showScrollToBottomButtonThreshold {
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
        } else if scrollToBottomWrapperView.alpha > 0.9 && position < showScrollToBottomButtonThreshold {
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
    
    private func toggleStickerPanel(delay: TimeInterval) {
        stickerPanelContainerHeightConstraint.constant = ConversationKeyboardManager.lastKeyboardHeight
        inputWrapperBottomConstraint.constant = isShowingStickerPanel ? bottomSafeAreaInset : stickerPanelContainerHeightConstraint.constant
        let newAlpha: CGFloat = isShowingStickerPanel ? 0 : 1
        stickerKeyboardSwitcherButton.setImage(isShowingStickerPanel ? #imageLiteral(resourceName: "ic_chat_sticker") : #imageLiteral(resourceName: "ic_chat_keyboard"), for: .normal)
        sendButton.isHidden = !isShowingStickerPanel || !inputTextView.hasText
        toggleStickerPanelSizeButton.isHidden = isShowingStickerPanel
        isStickerPanelMax = false
        toggleStickerPanelSizeButton.setImage(#imageLiteral(resourceName: "ic_chat_panel_max"), for: .normal)
        let offset = inputWrapperBottomConstraint.constant - lastInputWrapperBottomConstant
        UIView.animate(withDuration: 0, delay: delay, options: [], animations: {
            UIView.setAnimationCurve(.overdamped)
            self.stickerInputContainerView.alpha = newAlpha
            self.audioInputContainerView.isHidden = !self.isShowingStickerPanel
            if self.isShowingStickerPanel {
                self.dismissPanelsButton.alpha = 0
            }
            self.view.layoutIfNeeded()
            let contentOffsetY = self.tableView.contentOffset.y
            self.updateTableViewContentInset()
            self.tableView.setContentOffsetYSafely(contentOffsetY + offset)
        }) { (_) in
            self.isShowingStickerPanel = !self.isShowingStickerPanel
            self.lastInputWrapperBottomConstant = self.inputWrapperBottomConstraint.constant
        }
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
    
    private func updateTableViewContentInset() {
        var inset: UIEdgeInsets
        if #available(iOS 11.0, *), let safeAreaInsets = UIApplication.shared.keyWindow?.rootViewController?.view.safeAreaInsets {
            inset = safeAreaInsets
            let statusBarHeight = max(statusBarPlaceholderHeightConstraint.constant, UIApplication.shared.statusBarFrame.height)
            inset.top = max(statusBarHeight, inset.top)
        } else {
            inset = UIEdgeInsets(top: UIApplication.shared.statusBarFrame.height, left: 0, bottom: 0, right: 0)
        }
        inset.top += titleViewHeightConstraint.constant
        let quotePreviewViewHeight = isShowingQuotePreviewView ? quotePreviewView.frame.height : 0
        let inputWrapperHeight = ceil(inputTextViewTopConstraint.constant
            + inputTextViewHeightConstraint.constant
            + inputTextViewBottomConstraint.constant)
        inset.bottom = max(inputWrapperBottomConstraint.constant, inset.bottom)
            + quotePreviewViewHeight
            + inputWrapperHeight
        tableView.scrollIndicatorInsets = inset
        inset.bottom += MessageViewModel.bottomSeparatorHeight
        tableView.contentInset = inset
    }
    
    private func setQuoteViewHidden(_ hidden: Bool) {
        if hidden {
            quoteMessageId = nil
        }
        quoteViewShowConstraint.priority = hidden ? .defaultLow : .defaultHigh
        quoteViewHiddenConstraint.priority = hidden ? .defaultHigh : .defaultLow
        inputTextViewLeadingShrinkConstraint.priority = hidden ? .almostRequired : .defaultLow
        inputTextViewLeadingExpandedConstraint.priority = hidden ? .defaultLow : .almostRequired
        audioInputContainerView.isHidden = !hidden
        stickerKeyboardSwitcherButton.isHidden = !hidden
        sendButton.isHidden = false
        UIView.animate(withDuration: animationDuration) {
            self.updateTableViewContentInset()
            self.view.layoutIfNeeded()
        }
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
        guard let id = id, let indexPath = dataSource?.indexPath(where: { $0.messageId == id }) else {
            return
        }
        var contentViews = [UIView]()
        let cell = tableView.cellForRow(at: indexPath)
        if let cell = cell as? PhotoRepresentableMessageCell {
            contentViews = [cell.contentImageView,
                            cell.shadowImageView,
                            cell.timeLabel,
                            cell.statusImageView]
        }
        if let cell = cell as? AttachmentExpirationHintingMessageCell {
            contentViews.append(cell.operationButton)
        }
        if let cell = cell as? VideoMessageCell {
            contentViews.append(cell.lengthLabel)
        }
        contentViews.forEach {
            $0.isHidden = hidden
        }
    }
    
    private func makeInputTextViewResignFirstResponderIfItIs() {
        guard inputTextView.isFirstResponder else {
            return
        }
        keyboardManager.inputAccessoryViewHeight = 0
        inputTextView.resignFirstResponder()
    }
    
    private func frameOfPhotoRepresentableCell(_ cell: PhotoRepresentableMessageCell) -> CGRect {
        var rect = cell.contentImageView.convert(cell.contentImageView.bounds, to: view)
        if UIApplication.shared.statusBarFrame.height == StatusBarHeight.inCall {
            rect.origin.y += (StatusBarHeight.inCall - StatusBarHeight.normal)
        }
        return rect
    }
    
}

// MARK: - Helpers
extension ConversationViewController {
    
    private var trimmedMessageDraft: String {
        return inputTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func saveDraft() {
        guard !conversationId.isEmpty else {
            return
        }
        CommonUserDefault.shared.setConversationDraft(conversationId, draft: trimmedMessageDraft)
    }
    
    private func reloadParticipants() {
        guard dataSource?.category == .group else {
            return
        }
        if Thread.isMainThread {
            participantsLabel.text = Localized.GROUP_SECTION_TITLE_MEMBERS(count: 0)
        }
        let conversationId = self.conversationId
        DispatchQueue.global().async { [weak self] in
            if ParticipantDAO.shared.isExistParticipant(conversationId: conversationId) {
                let participants = ParticipantDAO.shared.participants(conversationId: conversationId)
                self?.role = participants.first(where: { $0.userId == AccountAPI.shared.accountUserId })?.role ?? ""
                self?.participants = participants
                DispatchQueue.main.async { [weak self] in
                    guard let weakSelf = self else {
                        return
                    }
                    weakSelf.unblockButton.isHidden = true
                    weakSelf.deleteConversationButton.isHidden = true
                    weakSelf.audioInputContainerView.isHidden = CommonUserDefault.shared.getConversationDraft(conversationId) != nil
                    if weakSelf.dataSource?.category == .group {
                        weakSelf.participantsLabel.text = Localized.GROUP_SECTION_TITLE_MEMBERS(count: weakSelf.participants.count)
                    }
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let weakSelf = self else {
                        return
                    }
                    weakSelf.participantsLabel.text = Localized.GROUP_REMOVE_TITLE
                    weakSelf.deleteConversationButton.isHidden = false
                    weakSelf.audioInputContainerView.isHidden = true
                }
            }
        }
    }
    
    private func openDocumentAction(message: MessageItem) {
        guard let mediaUrl = message.mediaUrl else {
            return
        }
        let url = MixinFile.url(ofChatDirectory: .files, filename: mediaUrl)
        guard FileManager.default.fileExists(atPath: url.path)  else {
            UIApplication.trackError("ConversationViewController", action: "openDocumentAction file not exist")
            return
        }
        previewDocumentController = UIDocumentInteractionController(url: url)
        previewDocumentController?.delegate = self
        if !(previewDocumentController?.presentPreview(animated: true) ?? false) {
            previewDocumentController?.presentOpenInMenu(from: CGRect.zero, in: self.view, animated: true)
        }
    }

    private func showLoading() {
        loadingView.isHidden = false
        loadingView.startAnimating()
        titleStackView.isHidden = true
    }

    private func hideLoading() {
        loadingView.isHidden = true
        loadingView.stopAnimating()
        titleStackView.isHidden = false
    }
    
    private func open(url: URL) {
        guard !UrlWindow.checkUrl(url: url) else {
            return
        }
        guard !conversationId.isEmpty else {
            return
        }
        presentWebWindow(withURL: url)
    }
    
    private func presentWebWindow(withURL url: URL) {
        let window = WebWindow.instance(conversationId: conversationId)
        window.controller = self
        window.presentPopupControllerAnimated(url: url)
    }
    
}

// MARK: - Embedded classes
extension ConversationViewController {
    
    struct Position {
        let messageId: String
        let offset: CGFloat
    }
    
}
