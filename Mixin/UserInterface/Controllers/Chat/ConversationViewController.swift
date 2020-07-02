import UIKit
import MobileCoreServices
import AVKit
import Photos
import MixinServices
import TexturedMaaku

class ConversationViewController: UIViewController {
    
    static var positions = [String: Position]()
    static var allowReportSingleMessage = false
    
    @IBOutlet weak var navigationBarView: UIView!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tableView: ConversationTableView!
    @IBOutlet weak var userHandleWrapperView: UserHandleWrapperView!
    @IBOutlet weak var accessoryButtonsWrapperView: HittestBypassWrapperView!
    @IBOutlet weak var mentionWrapperView: UIView!
    @IBOutlet weak var mentionCountLabel: InsetLabel!
    @IBOutlet weak var scrollToBottomWrapperView: UIView!
    @IBOutlet weak var scrollToBottomButton: UIButton!
    @IBOutlet weak var unreadBadgeLabel: UILabel!
    @IBOutlet weak var announcementBadgeView: UIView!
    @IBOutlet weak var inputWrapperView: UIView!
    @IBOutlet weak var inputWrapperTopShadowView: TopShadowView!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var loadingView: ActivityIndicatorView!
    @IBOutlet weak var titleStackView: UIStackView!
    
    @IBOutlet weak var navigationBarTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var mentionWrapperHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollToBottomWrapperHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var accessoryButtonsWrapperTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var accessoryButtonsWrapperBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var announcementBadgeHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var announcementBadgeBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputWrapperHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var showInputWrapperConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideInputWrapperConstraint: NSLayoutConstraint!
    
    var dataSource: ConversationDataSource!
    var conversationId: String {
        return dataSource.conversationId
    }
    var statusBarHidden = false {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    // Margin to navigation title bar
    private let minInputWrapperTopMargin: CGFloat = {
        if ScreenSize.current <= .inch4 {
            return 60
        } else {
            return 112
        }
    }()
    private let showScrollToBottomButtonThreshold: CGFloat = 150
    private let loadMoreMessageThreshold = 20
    private let animationDuration: TimeInterval = 0.3
    
    private var ownerUser: UserItem?
    private var quotingMessageId: String?
    private var isShowingMenu = false
    private var isAppearanceAnimating = true
    private var adjustTableViewContentOffsetWhenInputWrapperHeightChanges = true
    private var didManuallyStoppedTableViewDecelerating = false
    private var numberOfParticipants: Int?
    private var isMember = true
    private var messageIdToFlashAfterAnimationFinished: String?
    private var tapRecognizer: UITapGestureRecognizer!
    private var reportRecognizer: UILongPressGestureRecognizer!
    private var resizeInputRecognizer: ResizeInputWrapperGestureRecognizer!
    private var conversationInputViewController: ConversationInputViewController!
    private var previewDocumentController: UIDocumentInteractionController?
    private var previewDocumentMessageId: String?
    private var myInvitation: Message?
    private var isShowingKeyboard = false
    private var groupCallIndicatorCenterYConstraint: NSLayoutConstraint!
    
    private(set) lazy var imagePickerController = ImagePickerController(initialCameraPosition: .rear, cropImageAfterPicked: false, parent: self, delegate: self)
    
    private lazy var userHandleViewController = R.storyboard.chat.user_handle()!
    private lazy var multipleSelectionActionView = R.nib.multipleSelectionActionView(owner: self)!
    private lazy var announcementBadgeContentView = R.nib.announcementBadgeContentView(owner: self)!
    
    private lazy var strangerHintView: StrangerHintView = {
        let view = R.nib.strangerHintView(owner: nil)!
        view.blockButton.addTarget(self, action: #selector(blockAction(_:)), for: .touchUpInside)
        view.addContactButton.addTarget(self, action: #selector(addContactAction(_:)), for: .touchUpInside)
        return view
    }()
    
    private lazy var appReceptionView: AppReceptionView = {
        let view = R.nib.appReceptionView(owner: nil)!
        view.openHomePageButton.addTarget(conversationInputViewController,
                                          action: #selector(ConversationInputViewController.openOpponentAppAction(_:)),
                                          for: .touchUpInside)
        view.greetingButton.addTarget(self, action: #selector(greetAppAction(_:)), for: .touchUpInside)
        return view
    }()
    
    private lazy var invitationHintView: InvitationHintView = {
        let view = R.nib.invitationHintView(owner: nil)!
        view.exitButton.addTarget(self, action: #selector(exitGroupAndReportInviterAction(_:)), for: .touchUpInside)
        return view
    }()
    
    private lazy var groupCallIndicatorView: GroupCallIndicatorView = {
        let indicator = R.nib.groupCallIndicatorView(owner: self)!
        indicator.isHidden = true
        view.addSubview(indicator)
        indicator.snp.makeConstraints { (make) in
            make.trailing.equalToSuperview()
        }
        groupCallIndicatorCenterYConstraint = indicator.centerYAnchor.constraint(equalTo: view.topAnchor)
        groupCallIndicatorCenterYConstraint.constant = groupCallIndicatorCenterYLimitation.min
        groupCallIndicatorCenterYConstraint.isActive = true
        return indicator
    }()
    
    private lazy var cancelSelectionButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .background
        button.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16),
                                   adjustForContentSize: true)
        button.setTitleColor(.theme, for: .normal)
        button.setTitle(R.string.localizable.dialog_button_cancel(), for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        button.addTarget(self, action: #selector(endMultipleSelection), for: .touchUpInside)
        return button
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
    
    // Element is message_id
    private var mentionScrollingDestinations: [String] = [] {
        didSet {
            let wrapperAlpha: CGFloat
            if mentionScrollingDestinations.isEmpty {
                mentionWrapperHeightConstraint.constant = 4
                mentionCountLabel.isHidden = true
                wrapperAlpha = 0
            } else {
                mentionWrapperHeightConstraint.constant = 48
                mentionCountLabel.text = "\(mentionScrollingDestinations.count)"
                mentionCountLabel.isHidden = false
                wrapperAlpha = 1
            }
            UIView.animate(withDuration: 0.3) {
                self.mentionWrapperView.alpha = wrapperAlpha
                self.view.layoutIfNeeded()
                self.updateOverlays()
            }
        }
    }
    
    private var isUserHandleHidden = true {
        didSet {
            if isUserHandleHidden {
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
    
    private var maxInputWrapperHeight: CGFloat {
        return AppDelegate.current.mainWindow.frame.height
            - navigationBarView.frame.height
            - minInputWrapperTopMargin
    }
    
    private var groupCallIndicatorCenterYLimitation: (min: CGFloat, max: CGFloat) {
        let min = navigationBarView.frame.maxY + 30
        let max = inputWrapperView.frame.minY - 30
        return (min, max)
    }
    
    override var prefersStatusBarHidden: Bool {
        return statusBarHidden
    }
    
    // MARK: - Life cycle
    deinit {
        AppGroupUserDefaults.User.currentConversationId = nil
        NotificationCenter.default.removeObserver(self)
    }
    
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
        if dataSource.category == .group {
            let hasUnreadAnnouncement = AppGroupUserDefaults.User.hasUnreadAnnouncement[conversationId] ?? false
            if hasUnreadAnnouncement {
                updateAnnouncementBadge(announcement: dataSource.conversation.announcement)
            } else {
                updateAnnouncementBadge(announcement: nil)
            }
        } else {
            showScamAnnouncementIfNeeded()
        }
        dataSource.ownerUser = ownerUser
        dataSource.tableView = tableView
        updateStrangerActionView()
        inputWrapperView.isHidden = false
        updateNavigationBar()
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
            conversationInputViewController.detectsMentionToken = true
        } else if let user = ownerUser {
            conversationInputViewController.inputBarView.isHidden = false
            conversationInputViewController.update(opponentUser: user)
            conversationInputViewController.detectsMentionToken = false
        }
        AppGroupUserDefaults.User.currentConversationId = conversationId
        dataSource.initData(completion: finishInitialLoading)
        NotificationCenter.default.addObserver(self, selector: #selector(conversationDidChange(_:)), name: .ConversationDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(userDidChange(_:)), name: .UserDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuControllerDidShowMenu(_:)), name: UIMenuController.didShowMenuNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuControllerDidHideMenu(_:)), name: UIMenuController.didHideMenuNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(participantDidChange(_:)), name: .ParticipantDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didAddMessageOutOfBounds(_:)), name: ConversationDataSource.newMessageOutOfVisibleBoundsNotification, object: dataSource)
        NotificationCenter.default.addObserver(self, selector: #selector(audioManagerWillPlayNextNode(_:)), name: AudioManager.willPlayNextNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willRecallMessage(_:)), name: SendMessageService.willRecallMessageNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateGroupCallIndicatorIfNeeded), name: CallService.didReceivePublishingWithoutActiveGroupCall, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        if dataSource.category == .group {
            CallService.shared.membersManager.loadMembersAsynchornouslyIfNeverLoaded(forConversationWith: conversationId)
        }
        updateGroupCallIndicatorIfNeeded()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isAppearanceAnimating = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isAppearanceAnimating = false
        if let user = self.ownerUser {
            let job = RefreshUserJob(userIds: [user.userId])
            ConcurrentJobQueue.shared.addJob(job: job)
        }
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
        SendMessageService.shared.sendReadMessages(conversationId: conversationId)
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateNavigationBarHeightAndTableViewTopInset()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard let previous = previousTraitCollection, traitCollection.preferredContentSizeCategory != previous.preferredContentSizeCategory else {
            return
        }
        let messageId: String?
        if let indexPath = dataSource.focusIndexPath {
            messageId = dataSource.viewModel(for: indexPath)?.message.messageId
        } else {
            messageId = nil
        }
        dataSource.reload(initialMessageId: messageId)
    }
    
    // MARK: - Actions
    @IBAction func profileAction(_ sender: Any) {
        if let dataSource = dataSource, dataSource.category == .group {
            let vc = GroupProfileViewController(conversation: dataSource.conversation,
                                                numberOfParticipants: numberOfParticipants,
                                                isMember: isMember)
            present(vc, animated: true, completion: nil)
        } else if let user = ownerUser, user.isCreatedByMessenger {
            let vc = UserProfileViewController(user: user)
            present(vc, animated: true, completion: nil)
        }
    }
    
    @IBAction func backAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func scrollToBottomAction(_ sender: Any) {
        unreadBadgeValue = 0
        if let quotingMessageId = quotingMessageId, let indexPath = dataSource?.indexPath(where: { $0.messageId == quotingMessageId }) {
            self.quotingMessageId = nil
            scheduleCellBackgroundFlash(messageId: quotingMessageId)
            tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
        } else if let quotingMessageId = quotingMessageId, MessageDAO.shared.hasMessage(id: quotingMessageId) {
            self.quotingMessageId = nil
            messageIdToFlashAfterAnimationFinished = quotingMessageId
            reloadWithMessageId(quotingMessageId, scrollUpwards: true)
        } else {
            dataSource?.scrollToFirstUnreadMessageOrBottom()
        }
    }
    
    @IBAction func scrollToMentionAction(_ sender: Any) {
        guard let id = mentionScrollingDestinations.first else {
            return
        }
        if let indexPath = dataSource?.indexPath(where: { $0.messageId == id }) {
            mentionScrollingDestinations.removeFirst()
            scheduleCellBackgroundFlash(messageId: id)
            tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
        } else if MessageDAO.shared.hasMessage(id: id) {
            mentionScrollingDestinations.removeFirst()
            messageIdToFlashAfterAnimationFinished = id
            reloadWithMessageId(id, scrollUpwards: true)
        }
    }
    
    @IBAction func multipleSelectionAction(_ sender: Any) {
        switch multipleSelectionActionView.intent {
        case .forward:
            let messages = dataSource.selectedViewModels.values
                .map({ $0.message })
                .sorted(by: { $0.createdAt < $1.createdAt })
            let vc = MessageReceiverViewController.instance(content: .messages(messages))
            navigationController?.pushViewController(vc, animated: true)
        case .delete:
            let viewModels = dataSource.selectedViewModels.values.map({ $0 })
            let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            if !viewModels.contains(where: { $0.message.userId != myUserId || !$0.message.canRecall }) {
                controller.addAction(UIAlertAction(title: Localized.ACTION_DELETE_EVERYONE, style: .destructive, handler: { (_) in
                    if AppGroupUserDefaults.User.hasShownRecallTips {
                        self.deleteForEveryone(viewModels: viewModels)
                    } else {
                        self.showRecallTips(viewModels: viewModels)
                    }
                }))
            }
            controller.addAction(UIAlertAction(title: Localized.ACTION_DELETE_ME, style: .destructive, handler: { (_) in
                self.deleteForMe(viewModels: viewModels)
            }))
            controller.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
            self.present(controller, animated: true, completion: nil)
        }
    }
    
    @IBAction func dismissAnnouncementBadgeAction(_ sender: Any) {
        if dataSource.category == .group {
            AppGroupUserDefaults.User.hasUnreadAnnouncement.removeValue(forKey: conversationId)
        } else if let user = self.ownerUser {
            AppGroupUserDefaults.User.closeScamAnnouncementDate[user.userId] = Date()
        }
        updateAnnouncementBadge(announcement: nil)
    }
    
    @IBAction func groupCallIndicatorPanAction(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            recognizer.setTranslation(.zero, in: nil)
        case .changed:
            groupCallIndicatorCenterYConstraint.constant += recognizer.translation(in: nil).y
            recognizer.setTranslation(.zero, in: nil)
        case .ended:
            let (minY, maxY) = groupCallIndicatorCenterYLimitation
            let y = max(minY, min(maxY, groupCallIndicatorView.center.y))
            groupCallIndicatorCenterYConstraint.constant = y
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: view.layoutIfNeeded, completion: nil)
        default:
            break
        }
    }
    
    @IBAction func joinGroupCallAction(_ sender: Any) {
        startOrJoinGroupCall()
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
                        conversationInputViewController.view.backgroundColor = .background
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
        strangerHintView.blockButton.isBusy = true
        UserAPI.shared.blockUser(userId: userId) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.strangerHintView.blockButton.isBusy = false
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
        strangerHintView.addContactButton.isBusy = true
        UserAPI.shared.addFriend(userId: user.userId, full_name: user.fullName) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.strangerHintView.addContactButton.isBusy = false
            switch result {
            case .success(let userResponse):
                weakSelf.updateOwnerUser(withUserResponse: userResponse, updateDatabase: true)
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
    @objc func exitGroupAndReportInviterAction(_ sender: Any) {
        guard let inviterId = myInvitation?.userId else {
            return
        }

        let conversationId = self.conversationId

        func work(_: UIAlertAction) {
            let hud = Hud()
            if let view = navigationController?.view {
                hud.show(style: .busy, text: "", on: view)
            }

            DispatchQueue.global().async {
                switch UserAPI.shared.reportUser(userId: inviterId) {
                case let .success(user):
                    UserDAO.shared.updateUsers(users: [user], sendNotificationAfterFinished: false)
                    ConversationDAO.shared.deleteChat(conversationId: conversationId)
                    DispatchQueue.main.async {
                        hud.set(style: .notification, text: R.string.localizable.profile_report_success())
                        hud.scheduleAutoHidden()
                        UIApplication.homeNavigationController?.backToHome()
                    }
                case let .failure(error):
                    hud.set(style: .error, text: error.localizedDescription)
                    hud.scheduleAutoHidden()
                }
            }
        }
        
        let alert = UIAlertController(title: R.string.localizable.chat_exit_group_and_report_inviter_confirmation(), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_confirm(), style: .destructive, handler: work))
        alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    @objc func greetAppAction(_ sender: Any) {
        tableView.tableFooterView = nil
        dataSource.sendMessage(type: .SIGNAL_TEXT, value: "Hi")
    }
    
    @objc func tapAction(_ recognizer: UIGestureRecognizer) {
        if conversationInputViewController.audioViewController.hideLongPressHint() {
            return
        }
        if isShowingMenu {
            dismissMenu(animated: true)
            return
        }
        let tappedIndexPath = tableView.indexPathForRow(at: recognizer.location(in: tableView))
        let tappedViewModel: MessageViewModel? = {
            if let indexPath = tappedIndexPath {
                return dataSource?.viewModel(for: indexPath)
            } else {
                return nil
            }
        }()
        if tableView.allowsMultipleSelection {
            if let indexPath = tappedIndexPath, let viewModel = tappedViewModel {
                if let indexPaths = tableView.indexPathsForSelectedRows, indexPaths.contains(indexPath) {
                    tableView.deselectRow(at: indexPath, animated: true)
                    dataSource.selectedViewModels[viewModel.message.messageId] = nil
                } else if viewModel.supportsMultipleSelection(with: multipleSelectionActionView.intent) {
                    tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
                    dataSource.selectedViewModels[viewModel.message.messageId] = viewModel
                }
            }
            multipleSelectionActionView.numberOfSelection = dataSource.selectedViewModels.count
            return
        }
        if let indexPath = tappedIndexPath, let cell = tableView.cellForRow(at: indexPath) as? MessageCell, cell.contentFrame.contains(recognizer.location(in: cell)), let viewModel = tappedViewModel {
            let message = viewModel.message
            let isImageOrVideo = message.category.hasSuffix("_IMAGE") || message.category.hasSuffix("_VIDEO")
            let mediaStatusIsReady = message.mediaStatus == MediaStatus.DONE.rawValue || message.mediaStatus == MediaStatus.READ.rawValue
            if let quoteMessageId = viewModel.message.quoteMessageId, !quoteMessageId.isEmpty, let quote = cell.quotedMessageViewIfLoaded, quote.bounds.contains(recognizer.location(in: quote)) {
                if let indexPath = dataSource?.indexPath(where: { $0.messageId == quoteMessageId }) {
                    quotingMessageId = message.messageId
                    scheduleCellBackgroundFlash(messageId: quoteMessageId)
                    tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
                } else if MessageDAO.shared.hasMessage(id: quoteMessageId) {
                    quotingMessageId = message.messageId
                    messageIdToFlashAfterAnimationFinished = quoteMessageId
                    reloadWithMessageId(quoteMessageId, scrollUpwards: false)
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
                if shareUserId == myUserId {
                    guard let account = LoginManager.shared.account else {
                        return
                    }
                    let user = UserItem.createUser(from: account)
                    let vc = UserProfileViewController(user: user)
                    present(vc, animated: true, completion: nil)
                } else if let user = UserDAO.shared.getUser(userId: shareUserId), user.isCreatedByMessenger {
                    let vc = UserProfileViewController(user: user)
                    present(vc, animated: true, completion: nil)
                }
            } else if message.category.hasSuffix("_POST") {
                PostViewController.presentInstance(with: message, asChildOf: self)
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
            } else if message.category == MessageCategory.APP_CARD.rawValue, let appCard = message.appCard {
                conversationInputViewController.dismiss()
                openAppCard(appCard: appCard, sendUserId: message.userId)
            } else if message.category.hasSuffix("_LOCATION"), let location = message.location {
                let vc = LocationPreviewViewController(location: location)
                let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.chat_menu_location())
                navigationController?.pushViewController(container, animated: true)
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
        let alc = UIAlertController(title: Localized.REPORT_TITLE, message: MixinServer.httpUrl, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.REPORT_BUTTON, style: .default, handler: { [weak self](_) in
            self?.report(conversationId: conversationId, shareFile: false)
        }))
        alc.addAction(UIAlertAction(title: R.string.localizable.report_share(), style: .default, handler: { [weak self](_) in
            self?.report(conversationId: conversationId, shareFile: true)
        }))
        if !Self.allowReportSingleMessage {
            alc.addAction(UIAlertAction(title: R.string.localizable.report_message(), style: .default, handler: { (_) in
                Self.allowReportSingleMessage = true
            }))
        }

        if myIdentityNumber == "762532" || myIdentityNumber == "26596" {
            if let userId = ownerUser?.userId, dataSource.category == .contact {
                alc.addAction(UIAlertAction(title: R.string.localizable.report_copy_user_id(), style: .default, handler: {(_) in
                    UIPasteboard.general.string = userId
                }))
            }
            alc.addAction(UIAlertAction(title: R.string.localizable.report_copy_conversation_id(), style: .default, handler: { (_) in
                UIPasteboard.general.string = self.conversationId
            }))
        }

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
            if let dataSource = dataSource, dataSource.category == .group {
                dataSource.conversation.announcement = conversation.announcement
                let hasUnreadAnnouncement = AppGroupUserDefaults.User.hasUnreadAnnouncement[conversationId] ?? false
                let canShowAnnouncement = ScreenSize.current > .inch4 || !isShowingKeyboard
                if hasUnreadAnnouncement && canShowAnnouncement {
                    updateAnnouncementBadge(announcement: conversation.announcement)
                } else {
                    updateAnnouncementBadge(announcement: nil)
                }
            }
            hideLoading()
        case .startedUpdateConversation:
            showLoading()
        case let .updateMessageMentionStatus(messageId, newStatus):
            if newStatus == .MENTION_READ {
                mentionScrollingDestinations.removeAll(where: { $0 == messageId })
            }
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
            updateStrangerActionView()
        }
        hideLoading()
        dataSource?.ownerUser = ownerUser
        updateInvitationHintView()
        showScamAnnouncementIfNeeded()
    }
    
    @objc func menuControllerDidShowMenu(_ notification: Notification) {
        isShowingMenu = true
    }
    
    @objc func menuControllerDidHideMenu(_ notification: Notification) {
        isShowingMenu = false
        conversationInputViewController.textView.overrideNext = nil
    }
    
    @objc func participantDidChange(_ notification: Notification) {
        guard isViewLoaded, let conversationId = notification.object as? String, conversationId == self.conversationId else {
            return
        }
        updateSubtitleAndInputBar()
        dataSource.queue.async { [weak self] in
            let users = ParticipantDAO.shared.getParticipants(conversationId: conversationId)
            DispatchQueue.main.sync {
                self?.userHandleViewController.users = users
            }
        }
    }
    
    @objc func didAddMessageOutOfBounds(_ notification: Notification) {
        if let count = notification.userInfo?[ConversationDataSource.UserInfoKey.unreadMessageCount] as? Int {
            unreadBadgeValue += count
        }
        if let ids = notification.userInfo?[ConversationDataSource.UserInfoKey.mentionedMessageIds] as? [String] {
            mentionScrollingDestinations.append(contentsOf: ids)
        }
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
    
    @objc func willRecallMessage(_ notification: Notification) {
        guard let messageId = notification.userInfo?[SendMessageService.UserInfoKey.messageId] as? String, messageId == previewDocumentMessageId else {
            return
        }
        previewDocumentController?.dismissPreview(animated: true)
        previewDocumentController?.dismissMenu(animated: true)
        previewDocumentController = nil
        previewDocumentMessageId = nil
    }
    
    @objc func updateGroupCallIndicatorIfNeeded() {
        guard dataSource.category == .group else {
            return
        }
        CallService.shared.membersManager.getMemberUserIds(forConversationWith: conversationId) { [weak self] (ids) in
            guard let self = self else {
                return
            }
            let hasCall = !ids.isEmpty
            self.groupCallIndicatorView.isHidden = !hasCall
        }
    }
    
    @objc func endMultipleSelection() {
        dataSource.selectedViewModels.removeAll()
        for cell in tableView.visibleCells.compactMap({ $0 as? MessageCell }) {
            cell.setMultipleSelecting(false, intent: nil, animated: true)
        }
        tableView.indexPathsForSelectedRows?.forEach({ (indexPath) in
            tableView.deselectRow(at: indexPath, animated: true)
        })
        tableView.allowsMultipleSelection = false
        cancelSelectionButton.removeFromSuperview()
        
        showInputWrapperConstraint.priority = .defaultHigh
        hideInputWrapperConstraint.priority = .defaultLow
        UIView.animateKeyframes(withDuration: 0.4, delay: 0, options: [], animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1) {
                let old = self.multipleSelectionActionView.frame.height
                let new = self.inputWrapperHeightConstraint.constant
                self.updateTableViewBottomInsetWithBottomBarHeight(old: old, new: new, animated: false)
            }
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5) {
                self.multipleSelectionActionView.frame.origin.y = self.view.bounds.height
            }
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                self.view.layoutIfNeeded()
            }
        }, completion: { _ in
            self.multipleSelectionActionView.removeFromSuperview()
        })
    }
    
    @objc func keyboardWillShow(_ notification: Notification) {
        isShowingKeyboard = true
        if ScreenSize.current <= .inch4 {
            updateAnnouncementBadge(announcement: nil)
        }
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        isShowingKeyboard = false
        if dataSource.category == .group {
            let hasUnreadAnnouncement = AppGroupUserDefaults.User.hasUnreadAnnouncement[conversationId] ?? false
            if ScreenSize.current <= .inch4 && hasUnreadAnnouncement {
                updateAnnouncementBadge(announcement: dataSource.conversation.announcement)
            }
        } else {
            if ScreenSize.current <= .inch4 {
                showScamAnnouncementIfNeeded()
            }
        }
    }
    
    // MARK: - Interface
    func updateInputWrapper(for preferredContentHeight: CGFloat, animated: Bool) {
        let oldHeight = inputWrapperHeightConstraint.constant
        let newHeight = min(maxInputWrapperHeight, preferredContentHeight)
        inputWrapperHeightConstraint.constant = newHeight
        updateTableViewBottomInsetWithBottomBarHeight(old: oldHeight, new: newHeight, animated: animated)
    }
    
    // Overlays are user handle, accessory buttons and announcement badge
    func updateOverlays() {
        let handleHeight: CGFloat
        if isUserHandleHidden {
            handleHeight = 0
        } else {
            var maxHeight = userHandleWrapperView.frame.height
                - announcementBadgeContentView.minHeightConstraint.constant
            let shouldCalculateAccessoryButtonsHeight = scrollToBottomWrapperView.alpha == 1
                || mentionWrapperView.alpha == 1
                || !announcementBadgeView.subviews.isEmpty
            if shouldCalculateAccessoryButtonsHeight {
                maxHeight -= accessoryButtonsWrapperView.frame.height
                maxHeight -= accessoryButtonsWrapperBottomConstraint.constant
                maxHeight -= accessoryButtonsWrapperTopConstraint.constant
            }
            let height = userHandleWrapperView.bounds.height
                - userHandleViewController.tableHeaderView.frame.height
                + userHandleViewController.tableView.contentOffset.y
            handleHeight = min(maxHeight, height)
        }
        userHandleWrapperView.maskHeight = handleHeight
        if announcementBadgeBottomConstraint.constant != handleHeight {
            announcementBadgeBottomConstraint.constant = handleHeight
            view.layoutIfNeeded()
        }
    }
    
    func inputTextViewDidInputMentionCandidate(_ keyword: String?) {
        userHandleViewController.reload(with: keyword) { (hasContent) in
            self.isUserHandleHidden = !hasContent
            self.updateOverlays()
        }
    }
    
    func inputUserHandle(with user: UserItem) {
        conversationInputViewController.textView.replaceInputingMentionToken(with: user)
    }
    
    func presentDocumentPicker() {
        let vc = UIDocumentPickerViewController(documentTypes: ["public.item", "public.content"], in: .import)
        vc.delegate = self
        vc.modalPresentationStyle = .formSheet
        present(vc, animated: true, completion: nil)
    }
    
    func showTransfer() {
        guard let user = ownerUser else {
            return
        }
        let viewController: UIViewController
        if LoginManager.shared.account?.has_pin ?? false {
            viewController = TransferOutViewController.instance(asset: nil, type: .contact(user))
        } else {
            viewController = WalletPasswordViewController.instance(dismissTarget: .transfer(user: user))
        }
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    func showLocationPicker() {
        let vc = LocationPickerViewController(input: conversationInputViewController)
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.chat_menu_location())
        navigationController?.pushViewController(container, animated: true)
    }
    
    func showContactSelector() {
        let vc = ContactSelectorViewController.instance(conversationInputViewController: conversationInputViewController)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func callOwnerUserIfPresent() {
        guard let ownerUser = dataSource.ownerUser else {
            return
        }
        CallService.shared.requestStartPeerToPeerCall(remoteUser: ownerUser)
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
        let userInfo = ["source": "Conversation", "identityNumber": app.appNumber]
        reporter.report(event: .openApp, userInfo: userInfo)
        MixinWebViewController.presentInstance(with: .init(conversationId: conversationId, app: app), asChildOf: self)
    }
    
    func startOrJoinGroupCall() {
        guard dataSource.category == .group else {
            return
        }
        let conversation = dataSource.conversation
        CallService.shared.membersManager.getMemberUserIds(forConversationWith: conversationId) { [weak self] (ids) in
            if ids.isEmpty {
                let picker = GroupCallMemberPickerViewController(conversation: conversation)
                picker.appearance = .startNewCall
                picker.onConfirmation = { (members) in
                    CallService.shared.requestStartGroupCall(conversation: conversation,
                                                             invitingMembers: members)
                }
                self?.present(picker, animated: true, completion: nil)
            } else {
                CallService.shared.showJoinGroupCallConfirmation(conversation: conversation, memberIds: ids)
            }
        }
    }
    
    // MARK: - Class func
    class func instance(conversation: ConversationItem, highlight: ConversationDataSource.Highlight? = nil) -> ConversationViewController {
        let vc = R.storyboard.chat.conversation()!
        let dataSource = ConversationDataSource(conversation: conversation, highlight: highlight)
        if dataSource.category == .contact {
            vc.ownerUser = UserDAO.shared.getUser(userId: dataSource.conversation.ownerId)
        }
        vc.dataSource = dataSource
        return vc
    }
    
    class func instance(ownerUser: UserItem) -> ConversationViewController {
        let vc = R.storyboard.chat.conversation()!
        vc.ownerUser = ownerUser
        let conversationId = ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: ownerUser.userId)
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
            if tableView.allowsMultipleSelection {
                let intent = multipleSelectionActionView.intent
                cell.setMultipleSelecting(true, intent: intent, animated: false)
            } else {
                cell.setMultipleSelecting(false, intent: nil, animated: false)
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
        return message.allowedSelectors.contains(action)
    }
    
    func conversationTableView(_ tableView: ConversationTableView, didSelectAction action: MessageAction, forIndexPath indexPath: IndexPath) {
        guard let viewModel = dataSource?.viewModel(for: indexPath) else {
            return
        }
        let message = viewModel.message
        switch action {
        case .copy:
            if ["_TEXT", "_POST"].contains(where: message.category.hasSuffix(_:)) {
                UIPasteboard.general.string = message.content
            }
        case .delete:
            beginMultipleSelection(on: indexPath, intent: .delete)
        case .forward:
            beginMultipleSelection(on: indexPath, intent: .forward)
        case .reply:
            conversationInputViewController.quote = (message, viewModel.thumbnail)
        case .addToStickers:
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
                let vc = StickerAddViewController.instance(source: .message(message))
                navigationController?.pushViewController(vc, animated: true)
            }
        case .report:
            report(conversationId: conversationId, shareFile: false, message: message)
        }
    }
}

// MARK: - UIScrollViewDelegate
extension ConversationViewController: UIScrollViewDelegate {
    
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
        if let id = self.messageIdToFlashAfterAnimationFinished, let indexPath = self.dataSource.indexPath(where: { $0.messageId == id }) {
            if self.flashCellBackground(at: indexPath) {
                self.messageIdToFlashAfterAnimationFinished = nil
            }
        }
    }
    
}

// MARK: - UITableViewDelegate
extension ConversationViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let dataSource = dataSource else {
            return
        }
        if !isAppearanceAnimating {
            // Keep focusIndexPath until viewDidAppear
            dataSource.focusIndexPath = indexPath
        }
        if indexPath.section == 0 && indexPath.row <= loadMoreMessageThreshold {
            dataSource.loadMoreAboveIfNeeded()
        }
        if let lastIndexPath = dataSource.lastIndexPath, indexPath.section == lastIndexPath.section, indexPath.row >= lastIndexPath.row - loadMoreMessageThreshold {
            dataSource.loadMoreBelowIfNeeded()
        }

        let message = dataSource.viewModel(for: indexPath)?.message
        let messageId = message?.messageId
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
        if let message = message, let hasMentionRead = message.hasMentionRead, !hasMentionRead {
            message.hasMentionRead = true
            mentionScrollingDestinations.removeAll(where: { $0 == message.messageId })
            dataSource.queue.async {
                SendMessageService.shared.sendMentionMessageRead(conversationId: message.conversationId,
                                                                 messageId: message.messageId)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? PhotoRepresentableMessageCell {
            setCell(cell, contentViewHidden: false)
        }
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
        nil
    }
    
    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        if let label = tableView.hitTest(point, with: nil) as? TextMessageLabel, label.canResponseTouch(at: tableView.convert(point, to: label)) {
            return nil
        } else {
            return contextMenuConfigurationForRow(at: indexPath)
        }
    }
    
    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        previewForContextMenu(with: configuration)
    }
    
    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        previewForContextMenu(with: configuration)
    }
    
}

// MARK: - DetailInfoMessageCellDelegate
extension ConversationViewController: DetailInfoMessageCellDelegate {
    
    func detailInfoMessageCellDidSelectFullname(_ cell: DetailInfoMessageCell) {
        guard let indexPath = tableView.indexPath(for: cell), let message = dataSource?.viewModel(for: indexPath)?.message, let user = UserDAO.shared.getUser(userId: message.userId) else {
            return
        }
        let vc = UserProfileViewController(user: user)
        present(vc, animated: true, completion: nil)
    }
    
}

// MARK: - AppButtonGroupMessageCellDelegate
extension ConversationViewController: AppButtonGroupMessageCellDelegate {
    
    func appButtonGroupMessageCell(_ cell: AppButtonGroupMessageCell, didSelectActionAt index: Int) {
        guard let indexPath = tableView.indexPath(for: cell), let message = dataSource?.viewModel(for: indexPath)?.message, let appButtons = message.appButtons, index < appButtons.count else {
            return
        }
        openAction(action: appButtons[index].action, sendUserId: message.userId)
    }
    
    @available(iOS 13.0, *)
    func contextMenuConfigurationForAppButtonGroupMessageCell(_ cell: AppButtonGroupMessageCell) -> UIContextMenuConfiguration? {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return nil
        }
        return contextMenuConfigurationForRow(at: indexPath)
    }
    
    @available(iOS 13.0, *)
    func previewForHighlightingContextMenuOfAppButtonGroupMessageCell(_ cell: AppButtonGroupMessageCell, with configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        previewForContextMenu(with: configuration)
    }
    
    @available(iOS 13.0, *)
    func previewForDismissingContextMenuOfAppButtonGroupMessageCell(_ cell: AppButtonGroupMessageCell, with configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        previewForContextMenu(with: configuration)
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
        guard url.scheme != MixinInternalURL.scheme else {
            return
        }
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
        let vc = FileSendViewController.instance(documentUrl: url, conversationInputViewController: conversationInputViewController)
        navigationController?.pushViewController(vc, animated: true)
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
            let isParticipant = ParticipantDAO.shared.userId(myUserId, isParticipantOfConversationId: conversationId)
            if isParticipant {
                let count = ParticipantDAO.shared.getParticipantCount(conversationId: conversationId)
                DispatchQueue.main.sync {
                    guard let weakSelf = self else {
                        return
                    }
                    weakSelf.numberOfParticipants = count
                    weakSelf.isMember = isParticipant
                    weakSelf.conversationInputViewController.deleteConversationButton.isHidden = true
                    weakSelf.conversationInputViewController.inputBarView.isHidden = false
                    weakSelf.subtitleLabel.text = Localized.GROUP_SECTION_TITLE_MEMBERS(count: count)
                }
            } else {
                DispatchQueue.main.sync {
                    guard let weakSelf = self else {
                        return
                    }
                    if let number = weakSelf.numberOfParticipants {
                        weakSelf.numberOfParticipants = number - 1
                    }
                    weakSelf.isMember = isParticipant
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
            tableView.contentInset.top = titleViewTopConstraint.constant + titleViewHeightConstraint.constant
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
        updateStrangerActionView()
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
                updateOverlays()
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
                updateOverlays()
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
    
    private func updateStrangerActionView() {
        guard dataSource.category == .contact else {
            return
        }
        let conversationId = self.conversationId
        DispatchQueue.global().async { [weak self] in
            if let ownerUser = self?.ownerUser, ownerUser.relationship == Relationship.STRANGER.rawValue, !MessageDAO.shared.hasSentMessage(inConversationOf: conversationId) {
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        return
                    }
                    if ownerUser.isBot {
                        weakSelf.tableView.tableFooterView = weakSelf.appReceptionView
                    } else {
                        weakSelf.tableView.tableFooterView = weakSelf.strangerHintView
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self?.tableView.tableFooterView = nil
                }
            }
        }
    }
    
    private func updateInvitationHintView() {
        guard dataSource.category == .group else {
            return
        }
        let conversationId = self.conversationId
        DispatchQueue.global().async { [weak self] in
            let isInvitedByStranger: Bool
            let myInvitation = MessageDAO.shared.getInvitationMessage(conversationId: conversationId, inviteeUserId: myUserId)
            if let inviterId = myInvitation?.userId, !MessageDAO.shared.hasSentMessage(inConversationOf: conversationId), let inviter = UserDAO.shared.getUser(userId: inviterId), inviter.relationship != Relationship.FRIEND.rawValue {
                isInvitedByStranger = true
            } else {
                isInvitedByStranger = false
            }
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.myInvitation = myInvitation
                self.tableView.tableFooterView = isInvitedByStranger ? self.invitationHintView : nil
            }
        }
    }
    
    private func updateNavigationBarHeightAndTableViewTopInset() {
        titleViewTopConstraint.constant = max(20, AppDelegate.current.mainWindow.safeAreaInsets.top)
        tableView.contentInset.top = titleViewTopConstraint.constant + titleViewHeightConstraint.constant
        tableView.scrollIndicatorInsets.top = tableView.contentInset.top
    }
    
    // Returns true if the animation succeeds to perform, or false if cell not found
    @discardableResult
    private func flashCellBackground(at indexPath: IndexPath) -> Bool {
        guard let cell = self.tableView.cellForRow(at: indexPath) as? DetailInfoMessageCell else {
            return false
        }
        cell.updateAppearance(highlight: true, animated: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            cell.updateAppearance(highlight: false, animated: true)
        })
        return true
    }
    
    private func scheduleCellBackgroundFlash(messageId: String) {
        let visibleIndexPath = tableView.indexPathsForVisibleRows?.first(where: { (indexPath) -> Bool in
            guard let viewModel = dataSource.viewModel(for: indexPath) else {
                return false
            }
            return viewModel.message.messageId == messageId
        })
        if let indexPath = visibleIndexPath {
            _ = flashCellBackground(at: indexPath)
        } else {
            messageIdToFlashAfterAnimationFinished = messageId
        }
    }
    
    private func setCell(ofMessageId id: String?, contentViewHidden hidden: Bool) {
        guard let id = id, let cell = visiblePhotoRepresentableCell(of: id) else {
            return
        }
        setCell(cell, contentViewHidden: hidden)
    }
    
    private func setCell(_ cell: PhotoRepresentableMessageCell, contentViewHidden hidden: Bool) {
        var contentViews = [
            cell.contentImageView,
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
        userHandleWrapperView.addUserHandleView(userHandleViewController.view)
        userHandleViewController.didMove(toParent: self)
    }
    
    private func beginMultipleSelection(on indexPath: IndexPath, intent: MultipleSelectionIntent) {
        conversationInputViewController.textView.resignFirstResponder()
        conversationInputViewController.audioViewController.cancelIfRecording()
        UIView.performWithoutAnimation {
            navigationBarView.addSubview(cancelSelectionButton)
            cancelSelectionButton.snp.makeConstraints { (make) in
                make.leading.bottom.equalToSuperview()
                make.height.equalTo(56)
            }
            navigationBarView.layoutIfNeeded()
        }
        tableView.allowsMultipleSelection = true
        for cell in tableView.visibleCells.compactMap({ $0 as? MessageCell }) {
            cell.setMultipleSelecting(true, intent: intent, animated: true)
        }
        multipleSelectionActionView.intent = intent
        multipleSelectionActionView.numberOfSelection = 1
        multipleSelectionActionView.frame = CGRect(x: 0, y: view.bounds.height, width: view.bounds.width, height: multipleSelectionActionView.preferredHeight)
        multipleSelectionActionView.autoresizingMask = [.flexibleWidth]
        view.addSubview(multipleSelectionActionView)
        
        showInputWrapperConstraint.priority = .defaultLow
        hideInputWrapperConstraint.priority = .defaultHigh
        UIView.animateKeyframes(withDuration: 0.4, delay: 0, options: [], animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5) {
                self.view.layoutIfNeeded()
            }
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                let y = self.view.bounds.height - self.multipleSelectionActionView.preferredHeight
                self.multipleSelectionActionView.frame.origin.y = y
            }
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1) {
                let old = self.inputWrapperHeightConstraint.constant
                let new = self.multipleSelectionActionView.preferredHeight
                self.updateTableViewBottomInsetWithBottomBarHeight(old: old, new: new, animated: false)
            }
        }, completion: nil)
        DispatchQueue.main.async {
            self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            if let viewModel = self.dataSource.viewModel(for: indexPath) {
                self.dataSource.selectedViewModels[viewModel.message.messageId] = viewModel
            }
        }
    }
    
    private func updateTableViewBottomInsetWithBottomBarHeight(old: CGFloat, new: CGFloat, animated: Bool) {
        tableView.scrollIndicatorInsets.bottom = new - view.safeAreaInsets.bottom
        if animated {
            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationDuration(0.5)
            UIView.setAnimationCurve(.overdamped)
        }
        updateNavigationBarPositionWithInputWrapperViewHeight(oldHeight: old, newHeight: new)
        let bottomInset = new + MessageViewModel.bottomSeparatorHeight
        
        var newContentOffsetY = tableView.contentOffset.y + bottomInset - tableView.contentInset.bottom
        if isAppearanceAnimating, let focusIndexPath = dataSource?.focusIndexPath {
            let focusRectY = tableView.rectForRow(at: focusIndexPath).origin.y
            let availableSpace = focusRectY
                - tableView.contentOffset.y
                - tableView.contentInset.top
                - ConversationDateHeaderView.height
            if availableSpace > 0 {
                newContentOffsetY = min(newContentOffsetY, tableView.contentOffset.y + availableSpace)
            } else {
                newContentOffsetY = tableView.contentOffset.y
            }
        }
        tableView.contentInset.bottom = bottomInset
        if adjustTableViewContentOffsetWhenInputWrapperHeightChanges {
            tableView.setContentOffsetYSafely(newContentOffsetY)
        }
        if view.window != nil {
            view.layoutIfNeeded()
            updateOverlays()
        }
        if animated {
            UIView.commitAnimations()
        }
    }
    
    // Announcement badge will be hidden if announcement passed in is nil or empty
    private func updateAnnouncementBadge(announcement: String?) {
        if let announcement = announcement, !announcement.isEmpty {
            if announcementBadgeContentView.superview == nil {
                announcementBadgeView.addSubview(announcementBadgeContentView)
                announcementBadgeContentView.snp.makeEdgesEqualToSuperview()
            }
            announcementBadgeContentView.textView.text = announcement
            announcementBadgeContentView.layoutAsCompressed()
        } else {
            for subview in announcementBadgeView.subviews {
                subview.removeFromSuperview()
            }
        }
    }
    
    private func showScamAnnouncementIfNeeded() {
        guard let user = self.ownerUser else {
            return
        }
        guard user.isScam else {
            updateAnnouncementBadge(announcement: nil)
            return
        }
        let shouldShowAnnouncement: Bool
        if let date = AppGroupUserDefaults.User.closeScamAnnouncementDate[user.userId] {
            shouldShowAnnouncement = abs(date.timeIntervalSinceNow) > .oneDay
        } else {
            shouldShowAnnouncement = true
        }
        if shouldShowAnnouncement {
            announcementBadgeContentView.iconView.image = R.image.ic_warning()
            updateAnnouncementBadge(announcement: R.string.localizable.chat_warning_scam())
        } else {
            updateAnnouncementBadge(announcement: nil)
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
        let isGroup = dataSource.category == .group
        if isGroup {
            updateInvitationHintView()
        }
        hideLoading()
        let conversationId = self.conversationId
        dataSource.queue.async { [weak self] in
            let users = ParticipantDAO.shared.getParticipants(conversationId: conversationId)
            var ids = MessageMentionDAO.shared.unreadMessageIds(conversationId: conversationId)
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                UIView.performWithoutAnimation {
                    self.userHandleViewController.users = users
                    if isGroup {
                        let keyword = self.conversationInputViewController.textView.inputingMentionToken
                        self.userHandleViewController.reload(with: keyword) { (hasContent) in
                            self.isUserHandleHidden = !hasContent
                            self.updateOverlays()
                        }
                    }
                    ids.removeAll(where: self.dataSource.visibleMessageIds.contains)
                    self.mentionScrollingDestinations = ids
                }
            }
        }
    }
    
    private func openDocumentAction(message: MessageItem) {
        guard let mediaUrl = message.mediaUrl else {
            return
        }
        let url = AttachmentContainer.url(for: .files, filename: mediaUrl)
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

    private func openAppCard(appCard: AppCardData, sendUserId: String) {
        let action = appCard.action.absoluteString
        if let appId = appCard.appId, !appId.isEmpty {
            DispatchQueue.global().async { [weak self] in
                var app = AppDAO.shared.getApp(appId: appId)
                if app == nil {
                    if case let .success(response) = UserAPI.shared.showUser(userId: appId) {
                        UserDAO.shared.updateUsers(users: [response])
                        app = response.app
                    }
                }

                DispatchQueue.main.async {
                    self?.open(url: appCard.action, app: app)
                }
            }
        } else {
            openAction(action: action, sendUserId: sendUserId)
        }
    }

    private func openAction(action: String, sendUserId: String) {
        guard !openInputAction(action: action) else {
            return
        }
        guard let url = URL(string: action) else {
            return
        }

        if let app = conversationInputViewController?.opponentApp, app.appId == sendUserId {
            open(url: url, app: app)
        } else {
            DispatchQueue.global().async { [weak self] in
                var app = AppDAO.shared.getApp(ofUserId: sendUserId)
                if app == nil {
                    if case let .success(response) = UserAPI.shared.showUser(userId: sendUserId) {
                        UserDAO.shared.updateUsers(users: [response])
                        app = response.app
                    }
                }
                DispatchQueue.main.async {
                    self?.open(url: url, app: app)
                }
            }
        }
    }

    private func openInputAction(action: String) -> Bool {
        guard action.hasPrefix("input:"), action.count > 6 else {
            return false
        }

        let inputAction = String(action.suffix(action.count - 6))
        if !inputAction.isEmpty {
            dataSource.sendMessage(type: .SIGNAL_TEXT,
                                   quoteMessageId: nil,
                                   value: inputAction)
        }

        return true
    }

    private func open(url: URL, app: App? = nil) {
        guard !UrlWindow.checkUrl(url: url) else {
            return
        }
        guard !conversationId.isEmpty else {
            return
        }

        if let app = app {
            MixinWebViewController.presentInstance(with: .init(conversationId: conversationId, url: url, app: app), asChildOf: self)
        } else {
            MixinWebViewController.presentInstance(with: .init(conversationId: conversationId, initialUrl: url), asChildOf: self)
        }
    }

    private func report(conversationId: String, shareFile: Bool, message: MessageItem? = nil) {
        DispatchQueue.global().async { [weak self] in
            let developID = myIdentityNumber == "762532" ? "31911" : "762532"
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

            Logger.write(conversationId: conversationId, log: "[Report][Websocket]...isReachable:\(NetworkManager.shared.isReachable)...isConnected:\(WebSocketService.shared.isConnected)...isRealConnected:\(WebSocketService.shared.isRealConnected)")

            if let message = message {
                var log = "[Report][Message][\(message.messageId)][\(message.category)][\(message.status)]...userId:\(message.userId)"
                if ["_IMAGE", "_VIDEO", "_AUDIO", "_LIVE"].contains(where: message.category.hasSuffix) {
                    log += """
                            ...mediaStatus:\(message.mediaStatus ?? "")
                            ...mediaUrl:\(message.mediaUrl ?? "")
                            ...mediaMimeType:\(message.mediaMimeType ?? "")
                            ...mediaSize:\(message.mediaSize ?? 0)
                            ...mediaDuration:\(message.mediaDuration ?? 0)
                            ...mediaLocalIdentifier:\(message.mediaLocalIdentifier ?? "")
                            ...mediaWidth:\(message.mediaWidth ?? 0)
                            ...mediaHeight:\(message.mediaHeight ?? 0)
                           """

                    if let mediaUrl = message.mediaUrl, !mediaUrl.isEmpty, !mediaUrl.hasPrefix("http") {
                        if message.category.hasSuffix("_IMAGE") {
                            let url = AttachmentContainer.url(for: .photos, filename: mediaUrl)
                            log += "...fileExists:\(FileManager.default.fileExists(atPath: url.path))...fileSize:\(FileManager.default.fileSize(url.path))"
                        } else if message.category.hasSuffix("_VIDEO") {
                            let url = AttachmentContainer.url(for: .videos, filename: mediaUrl)
                            log += "...fileExists:\(FileManager.default.fileExists(atPath: url.path))...fileSize:\(FileManager.default.fileSize(url.path))"
                        }
                    }
                }

                Logger.write(conversationId: conversationId, log: log, newSection: true)
            }

            guard let developUser = user, let url = Logger.export(conversationId: conversationId) else {
                return
            }
            let targetUrl = AttachmentContainer.url(for: .files, filename: url.lastPathComponent)
            do {
                try FileManager.default.copyItem(at: url, to: targetUrl)
                try FileManager.default.removeItem(at: url)
            } catch {
                return
            }
            guard FileManager.default.fileSize(targetUrl.path) > 0 else {
                return
            }

            if shareFile {
                DispatchQueue.main.async {
                    let inviteController = UIActivityViewController(activityItems: [targetUrl], applicationActivities: nil)
                    self?.navigationController?.present(inviteController, animated: true, completion: nil)
                }
            } else {
                let developConversationId = ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: developUser.userId)
                var message = Message.createMessage(category: MessageCategory.PLAIN_DATA.rawValue, conversationId: developConversationId, userId: myUserId)
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
    }
    
    private func deleteForMe(viewModels: [MessageViewModel]) {
        if let playingMessageId = AudioManager.shared.playingMessage?.messageId, viewModels.contains(where: { $0.message.messageId == playingMessageId }) {
            AudioManager.shared.stop()
        }
        for case let viewModel as AttachmentLoadingViewModel in viewModels {
            viewModel.cancelAttachmentLoading(isTriggeredByUser: true)
        }
        for viewModel in viewModels {
            dataSource?.queue.async { [weak self] in
                let message = viewModel.message
                guard let weakSelf = self, let indexPath = weakSelf.dataSource.indexPath(where: { $0.messageId == message.messageId }) else {
                    return
                }
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
        endMultipleSelection()
    }
    
    private func deleteForEveryone(viewModels: [MessageViewModel]) {
        if let playingMessageId = AudioManager.shared.playingMessage?.messageId, viewModels.contains(where: { $0.message.messageId == playingMessageId }) {
            AudioManager.shared.stop()
        }
        for case let viewModel as AttachmentLoadingViewModel in viewModels {
            viewModel.cancelAttachmentLoading(isTriggeredByUser: true)
        }
        DispatchQueue.global().async {
            for viewModel in viewModels {
                let message = viewModel.message
                SendMessageService.shared.recallMessage(messageId: message.messageId,
                                                        category: message.category,
                                                        mediaUrl: message.mediaUrl,
                                                        conversationId: message.conversationId,
                                                        status: message.status)
            }
        }
        endMultipleSelection()
    }
    
    private func showRecallTips(viewModels: [MessageViewModel]) {
        let alc = UIAlertController(title: R.string.localizable.chat_delete_tip(), message: "", preferredStyle: .alert)
        alc.addAction(UIAlertAction(title: R.string.localizable.action_learn_more(), style: .default, handler: { (_) in
            AppGroupUserDefaults.User.hasShownRecallTips = true
            UIApplication.shared.openURL(url: "https://mixinmessenger.zendesk.com/hc/articles/360028209571")
        }))
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_OK, style: .default, handler: { (_) in
            AppGroupUserDefaults.User.hasShownRecallTips = true
            self.deleteForEveryone(viewModels: viewModels)
        }))
        present(alc, animated: true, completion: nil)
    }
    
    private func reloadWithMessageId(_ messageId: String, scrollUpwards: Bool) {
        let scroll = scrollUpwards ? dataSource.scrollToBottomAndReload : dataSource.scrollToTopAndReload
        let flashingId = self.messageIdToFlashAfterAnimationFinished
        self.messageIdToFlashAfterAnimationFinished = nil
        scroll(messageId, {
            guard let indexPath = self.dataSource?.indexPath(where: { $0.messageId == messageId }) else {
                return
            }
            if scrollUpwards {
                self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: false)
            } else {
                self.tableView.scrollToRow(at: indexPath, at: .top, animated: false)
            }
            self.messageIdToFlashAfterAnimationFinished = flashingId
            self.tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
        })
    }
    
}

// MARK: - Context menu configs
@available(iOS 13.0, *)
extension ConversationViewController {
    
    private func contextMenuConfigurationForRow(at indexPath: IndexPath) -> UIContextMenuConfiguration? {
        guard !tableView.allowsMultipleSelection else {
            return nil
        }
        guard conversationTableView(self.tableView, hasActionsforIndexPath: indexPath) else {
            return nil
        }
        guard let message = dataSource?.viewModel(for: indexPath)?.message else {
            return nil
        }
        let actions = message.allowedActions.map { (action) -> UIAction in
            UIAction(title: action.title, image: action.image) { (_) in
                guard let indexPath = self.dataSource.indexPath(where: { $0.messageId == message.messageId }) else {
                    return
                }
                if action == .delete || action == .forward || action == .reply {
                    // Wait until context menu animation finished
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.conversationTableView(self.tableView, didSelectAction: action, forIndexPath: indexPath)
                    }
                } else {
                    self.conversationTableView(self.tableView, didSelectAction: action, forIndexPath: indexPath)
                }
            }
        }
        let identifier = message.messageId as NSString
        return UIContextMenuConfiguration(identifier: identifier, previewProvider: nil) { (elements) -> UIMenu? in
            UIMenu(title: "", children: actions)
        }
    }
    
    private func previewForContextMenu(with configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let identifier = configuration.identifier as? NSString else {
            return nil
        }
        let messageId = identifier as String
        guard let indexPath = dataSource.indexPath(where: { $0.messageId == messageId }), let cell = tableView.cellForRow(at: indexPath) as? MessageCell, cell.window != nil, let viewModel = dataSource.viewModel(for: indexPath) else {
            return nil
        }
        let param = UIPreviewParameters()
        param.backgroundColor = .clear
        
        if let viewModel = viewModel as? StickerMessageViewModel {
            param.visiblePath = UIBezierPath(roundedRect: viewModel.contentFrame,
                                             cornerRadius: StickerMessageCell.contentCornerRadius)
        } else if let viewModel = viewModel as? AppButtonGroupViewModel {
            param.visiblePath = UIBezierPath(roundedRect: viewModel.buttonGroupFrame,
                                             cornerRadius: AppButtonView.cornerRadius)
        } else {
            if viewModel.style.contains(.received) {
                if viewModel.style.contains(.tail) {
                    param.visiblePath = BubblePath.leftWithTail(frame: viewModel.backgroundImageFrame)
                } else {
                    param.visiblePath = BubblePath.left(frame: viewModel.backgroundImageFrame)
                }
            } else {
                if viewModel.style.contains(.tail) {
                    param.visiblePath = BubblePath.rightWithTail(frame: viewModel.backgroundImageFrame)
                } else {
                    param.visiblePath = BubblePath.right(frame: viewModel.backgroundImageFrame)
                }
            }
        }
        
        return UITargetedPreview(view: cell, parameters: param)
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
